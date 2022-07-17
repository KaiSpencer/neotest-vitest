---@diagnostic disable: undefined-field
local lib = require("neotest.lib")
local logger = require("neotest.logging")
local util = require("lspconfig").util

---@type neotest.Adapter
local adapter = { name = "neotest-vitest" }

adapter.root = lib.files.match_root_pattern("package.json")

function adapter.is_test_file(file_path)
  if file_path == nil then
    return false
  end

  if string.match(file_path, "__tests__") then
    return true
  end

  for _, x in ipairs({ "spec", "test" }) do
    for _, ext in ipairs({ "js", "jsx", "coffee", "ts", "tsx" }) do
      if string.match(file_path, x .. "%." .. ext .. "$") then
        return true
      end
    end
  end

  return false
end

---@async
---@return neotest.Tree | nil
function adapter.discover_positions(path)
  local query = [[
    ; -- Namespaces --
    ; Matches: `describe('context')`
    ((call_expression
      function: (identifier) @func_name (#eq? @func_name "describe")
      arguments: (arguments (string (string_fragment) @namespace.name) (arrow_function))
    )) @namespace.definition
    ; Matches: `describe.only('context')`
    ((call_expression
      function: (member_expression
        object: (identifier) @func_name (#any-of? @func_name "describe")
      )
      arguments: (arguments (string (string_fragment) @namespace.name) (arrow_function))
    )) @namespace.definition
    ; Matches: `describe.each(['data'])('context')`
    ((call_expression
      function: (call_expression
        function: (member_expression
          object: (identifier) @func_name (#any-of? @func_name "describe")
        )
      )
      arguments: (arguments (string (string_fragment) @namespace.name) (arrow_function))
    )) @namespace.definition

    ; -- Tests --
    ; Matches: `test('test') / it('test')`
    ((call_expression
      function: (identifier) @func_name (#any-of? @func_name "it" "test")
      arguments: (arguments (string (string_fragment) @test.name) (arrow_function))
    )) @test.definition
    ; Matches: `test.only('test') / it.only('test')`
    ((call_expression
      function: (member_expression
        object: (identifier) @func_name (#any-of? @func_name "test" "it")
      )
      arguments: (arguments (string (string_fragment) @test.name) (arrow_function))
    )) @test.definition
    ; Matches: `test.each(['data'])('test') / it.each(['data'])('test')`
    ((call_expression
      function: (call_expression
        function: (member_expression
          object: (identifier) @func_name (#any-of? @func_name "it" "test")
        )
      )
      arguments: (arguments (string (string_fragment) @test.name) (arrow_function))
    )) @test.definition
  ]]

  return lib.treesitter.parse_positions(path, query, { nested_tests = true })
end

local function getVitestCommand(path)
  local rootPath = util.find_node_modules_ancestor(path)
  local vitestBinary = util.path.join(rootPath, "node_modules", ".bin", "vitest")

  if util.path.exists(vitestBinary) then
    return vitestBinary
  end

  return "vitest"
end

local config_files = {
  "vitest.config.ts",
  "vitest.config.mts",
  "vitest.config.cts",
  "vitest.config.js",
  "vitest.config.mjs",
  "vitest.config.cjs",
  "vite.config.ts",
  "vite.config.mts",
  "vite.config.cts",
  "vite.config.js",
  "vite.config.mjs",
  "vite.config.cjs",
}

local vitestConfigPattern = util.root_pattern(config_files)

local function getVitestConfig(path)
  local rootPath = vitestConfigPattern(path)

  if not rootPath then
    return nil
  end

  for _, config_file in ipairs(config_files) do
    local abs_config_path = util.path.join(rootPath, config_file)
    if util.path.exists(abs_config_path) then
      return abs_config_path
    end
  end
end

local function escapeTestPattern(s)
  return s:gsub("%(", "%\\(")
    :gsub("%)", "%\\)")
    :gsub("%]", "%\\]")
    :gsub("%[", "%\\[")
    :gsub("%*", "%\\*")
    :gsub("%+", "%\\+")
    :gsub("%-", "%\\-")
    :gsub("%?", "%\\?")
    :gsub("%$", "%\\$")
    :gsub("%^", "%\\^")
    :gsub("%/", "%\\/")
end

---@param args neotest.RunArgs
---@return neotest.RunSpec | nil
function adapter.build_spec(args)
  local results_path = vim.fn.tempname() .. ".json"
  local tree = args.tree

  if not tree then
    return
  end

  local pos = args.tree:data()
  local testNamePattern = ".*"

  if pos.type == "test" then
    testNamePattern = escapeTestPattern(pos.name:gsub('"', "")) .. "$"
  end

  local binary = getVitestCommand(pos.path) or "vitest"
  local config = getVitestConfig(pos.path) or "vite.config.ts"
  local command = {}

  -- split by whitespace
  for w in binary:gmatch("%S+") do
    table.insert(command, w)
  end
  if util.path.exists(config) then
    -- only use config if available
    table.insert(command, "--config=" .. config)
  end

  for _, value in ipairs({
    "--reporter=verbose",
    "--reporter=json",
    "--outputFile=" .. results_path,
    "--testNamePattern=" .. testNamePattern,
    "--run",
    pos.path,
  }) do
    table.insert(command, value)
  end

  return {
    command = command,
    context = {
      results_path = results_path,
      file = pos.path,
    },
  }
end

local function cleanAnsi(s)
  return s:gsub("\x1b%[%d+;%d+;%d+;%d+;%d+m", "")
    :gsub("\x1b%[%d+;%d+;%d+;%d+m", "")
    :gsub("\x1b%[%d+;%d+;%d+m", "")
    :gsub("\x1b%[%d+;%d+m", "")
    :gsub("\x1b%[%d+m", "")
end

local function parsed_json_to_results(data, output_file, console_output)
  local tests = {}

  for _, testResult in pairs(data.testResults) do
    local testFn = testResult.name

    for _, assertionResult in pairs(testResult.assertionResults) do
      local status, name = assertionResult.status, assertionResult.title

      if name == nil then
        logger.error("Failed to find parsed test result ", assertionResult)
        return {}
      end

      local keyid = testFn

      for _, value in ipairs(assertionResult.ancestorTitles) do
        if value ~= "" then
          keyid = keyid .. "::" .. value
        end
      end

      keyid = keyid .. "::" .. name

      if status == "pending" then
        status = "skipped"
      end

      tests[keyid] = {
        status = status,
        short = name .. ": " .. status,
        output = console_output,
        location = assertionResult.location,
      }

      if not vim.tbl_isempty(assertionResult.failureMessages) then
        local errors = {}

        for i, failMessage in ipairs(assertionResult.failureMessages) do
          local msg = cleanAnsi(failMessage)
          local location = assertionResult.location

          errors[i] = {
            line = location and location.line - 1 or nil,
            column = (location and location.column or 1) - 1,
            message = msg,
          }

          tests[keyid].short = tests[keyid].short .. "\n" .. msg
        end

        tests[keyid].errors = errors
      end
    end
  end

  return tests
end

---@async
---@param spec neotest.RunSpec
---@param result neotest.StrategyResult
---@param tree neotest.Tree
---@return neotest.Result[]
function adapter.results(spec, result, tree)
  local output_file = spec.context.results_path

  local success, data = pcall(lib.files.read, output_file)

  if not success then
    logger.error("No test output file found ", output_file)
    return {}
  end

  local ok, parsed = pcall(vim.json.decode, data, { luanil = { object = true } })

  if not ok then
    logger.error("Failed to parse test output json ", output_file)
    return {}
  end

  local results = parsed_json_to_results(parsed, output_file, result.output)

  return results
end

local is_callable = function(obj)
  return type(obj) == "function" or (type(obj) == "table" and obj.__call)
end

setmetatable(adapter, {
  __call = function(_, opts)
    if is_callable(opts.vitestCommand) then
      getVitestCommand = opts.vitestCommand
    elseif opts.vitestCommand then
      getVitestCommand = function()
        return opts.vitestCommand
      end
    end
    if is_callable(opts.vitestConfigFile) then
      getVitestConfig = opts.vitestConfigFile
    elseif opts.vitestConfigFile then
      getVitestConfig = function()
        return opts.vitestConfigFile
      end
    end
    return adapter
  end,
})

return adapter
