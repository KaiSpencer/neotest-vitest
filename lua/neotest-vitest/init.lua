---@diagnostic disable: undefined-field
local lib = require("neotest.lib")
local logger = require("neotest.logging")

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
  ((call_expression
      function: (identifier) @func_name (#match? @func_name "^describe")
      arguments: (arguments (_) @namespace.name (arrow_function))
  )) @namespace.definition


  ((call_expression
      function: (identifier) @func_name (#match? @func_name "^it")
      arguments: (arguments (_) @test.name (arrow_function))
  ) ) @test.definition
  ((call_expression
      function: (member_expression) @func_name (#match? @func_name "^it")
      arguments: (arguments (_) @test.name (arrow_function))
  ) ) @test.definition
    ]]
    return lib.treesitter.parse_positions(path, query, { nested_tests = true })
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
        testNamePattern = pos.name
    end

    local binary = "vitest"
    if vim.fn.filereadable("node_modules/.bin/vitest") then
        binary = "node_modules/.bin/vitest"
    end

    local command = vim.tbl_flatten({
        binary,
        "--reporter=json",
        "--outputFile=" .. results_path,
        "--testNamePattern=" .. testNamePattern,
        "--run",
    })
    return {
        command = command,
        context = {
            results_path = results_path,
            file = pos.path,
        },
    }
end

local function cleanAnsi(s)
    return s
        :gsub("\x1b%[%d+;%d+;%d+;%d+;%d+m", "")
        :gsub("\x1b%[%d+;%d+;%d+;%d+m", "")
        :gsub("\x1b%[%d+;%d+;%d+m", "")
        :gsub("\x1b%[%d+;%d+m", "")
        :gsub("\x1b%[%d+m", "")
end

local function parsed_json_to_results(data, output_file)
    local tests = {}
    local failed = false

    local testFn = data.testResults[1].name
    for _, result in pairs(data.testResults[1].assertionResults) do
        local status, name = result.status, result.title
        if name == nil then
            logger.error("Failed to find parsed test result ", result)
            return {}, failed
        end
        local keyid = testFn
        for _, value in ipairs(result.ancestorTitles) do
            if value ~= "" then
                keyid = keyid .. "::" .. '"' .. value .. '"'
            end
        end
        keyid = keyid .. "::" .. '"' .. name .. '"'
        if status == "pending" then
            status = "skipped"
        end
        tests[keyid] = {
            status = status,
            short = name .. ": " .. status,
            output = output_file,
            location = result.location,
        }
        if result.failureMessages then
            failed = true
            local errors = {}
            for i, failMessage in ipairs(result.failureMessages) do
                local msg = cleanAnsi(failMessage)
                errors[i] = {
                    message = msg,
                }
                tests[keyid].short = tests[keyid].short .. "\n" .. msg
            end
            tests[keyid].errors = errors
        end
    end
    return tests, failed
end

---@async
---@param spec neotest.RunSpec
---@param result neotest.StrategyResult
---@param tree neotest.Tree
---@return neotest.Result[]
function adapter.results(spec, _, tree)
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

    local results, failed = parsed_json_to_results(parsed, output_file)
    for _, value in tree:iter() do
        if value.type == "file" or value.type == "namespace" then
            if results[value.status] == "passed" then
                results[value.id] = {
                    status = "passed",
                    output = output_file,
                }
            end

            if results[value.status] == "failed" then
                results[value.id].status = "failed"
            end
        end
    end
    return results
end

setmetatable(adapter, {
    __call = function()
        return adapter
    end,
})

return adapter
