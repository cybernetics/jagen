local P = {}
local System = require 'System'
local Target = require 'Target'

local format = string.format
local concat = table.concat

local packages = {}
local ninja = {
    supports_console_pool = true
}

local function check_ninja_features()
    local version = os.getenv('jagen_ninja_version')
    if not version then return end
    local major, minor = version:match('(%d+)%.(%d+)%.%d+')
    major, minor = tonumber(major), tonumber(minor)
    if major and minor then
        if major == 1 and minor < 5 then
            ninja.supports_console_pool = false
        end
    end
end

local function indent(n)
    return string.rep(' ', n or 4)
end

local function indented(line, n)
    return concat { indent(n), line }
end

local function separated(str)
    if not string.empty(str) then
        return str..(suffix or ' ')
    else
        return ''
    end
end

local function escape(s)
    s = string.gsub(s, "%$", "$$")
    s = string.gsub(s, " ", "$ ")
    s = string.gsub(s, ":", "$:")
    return s
end

local function nonempty(list)
    local out = {}
    for i = 1, #list do
        local item = list[i]
        if item and item ~= '' then
            table.insert(out, item)
        end
    end
    return out
end

local function join(list)
    return concat(list)
end

local function join_space(list)
    return concat(list, ' ')
end

local function join_nl(list)
    return concat(list, '\n')
end

local function join_escaped(list)
    return concat(list, ' $\n')
end

local function join_quoted(list)
    return join_space(collect(list, map(function (i)
                    return format("'%s'", escape(tostring(i)))
        end)))
end

local function quote(s)
    return format("'%s'", string.gsub(s or '', "%$", "$$"))
end

local function binding(k, v)
    return format('%s = %s', assert(k), tostring(assert(v)))
end

local function format_pool(name, depth)
    return format('pool %s\n%sdepth = %s', name, indent(4), depth)
end

local function format_rule(name, command)
    return format('rule %s\n%scommand = %s', name, indent(4), command)
end

local function format_outputs(outputs)
    local lines = { escape(outputs[1]) }
    if #outputs > 1 then
        extend(lines, map(function (x)
                    return indented(escape(tostring(x)), 6)
            end, sort(table.rest(outputs, 2))))
        append(lines, indent(12))
    end
    return join_escaped(lines)
end

local function format_inputs(inputs)
    local lines = { '' }
    extend(lines, sort(map(function (x)
                    return indented(escape(tostring(x)), 16)
        end, inputs or {})))
    return join_escaped(lines)
end

local function format_refresh(files, packages)
    local outputs = { 'build.ninja' }
    return format('build %s: refresh%s\n%s%s', format_outputs(outputs), format_inputs(files),
        indent(4), binding('description', 'refresh'))
end

local function format_phony(files)
    return format('build %s: phony', format_outputs(files))
end

local function format_build(build)
    local lines = { '' }

    local function format_uses(uses)
        local lines = {}
        if #uses > 0 then
            append(lines, ' ||')
            extend(lines, sort(map(function (x)
                            return indented(escape(tostring(x)), 16)
                end, uses or {})))
        end
        return join_escaped(lines)
    end

    append(lines, format('build %s: %s%s%s',
            format_outputs(build.outputs),
            assert(build.rule),
            format_inputs(build.inputs),
            format_uses(build.uses)))

    extend(lines, map(function (key)
                return indented(binding(key, build.vars[key]))
        end, sort(table.keys(build.vars))))

    return join_nl(lines)
end

local function format_stage(target, pkg)
    local config = target.config

    local function get_outputs()
        local outputs = { tostring(target) }
        return extend(outputs, target.outputs or {})
    end

    local function format_args()
        local command = { target.name, target.stage,
            config or quote('')
        }
        local arg = target.arg
        if type(arg) == 'string' or type(arg) == 'number' then
            arg = { tostring(arg) }
        end
        if type(arg) == 'table' then
            append(command, join_quoted(target.arg))
        end
        return join_space(command)
    end

    local vars = {
        description = target:__tostring(' '),
        args        = format_args(),
    }

    local uses = {}

    if config then
        local this = assert(pkg.configs[config])
        for spec in each(pkg.uses or {}, this.uses) do
            local use = Target.from_use(spec)
            local used = packages[use.name]
            if used then
                local config = use.config or used:has_config(config) and config
                if config then
                    append_uniq(Target.from_args(use.name, 'export', config), uses)
                end
            end
        end
    else
        for use in each(pkg.uses or {}) do
            append_uniq(Target.from_args(Target.from_use(use).name, 'export'), uses)
        end
        for this in pkg:each_config() do
            for use in each(this.uses or {}) do
                append_uniq(Target.from_args(Target.from_use(use).name, 'export'), uses)
            end
        end
    end

    if target.stage == 'clean' then
        uses = target.order_only or {}
    end

    vars.pool = target.pool

    for use in each(target.uses) do
        append_uniq(tostring(use), uses)
    end

    return format_build {
        rule    = 'stage',
        uses    = uses,
        inputs  = target.inputs,
        outputs = get_outputs(),
        vars    = vars
    }
end

local function format_package(name, pkg)
    local lines = {}
    for stage in pkg:each() do
        append(lines, format_stage(stage, pkg))
    end
    return join(lines)
end

local function assign_pools(packages)
    local function is_android_gradle(target, pkg)
        if target.stage == 'compile' then
            local build = pkg:get('build', target.config)
            return build and build.type == 'android-gradle'
        end
    end
    local function is_rust_toolchain(target, pkg)
        if target.stage == 'install' then
            local build = pkg:get('build', target.config)
            return build and build.type == 'rust-toolchain'
        end
    end
    local function is_interactive(target)
        return target.interactive
    end
    local function assign_interactive(targets)
        if table.find(targets, is_interactive) then
            for target in each(targets) do
                target.interactive = true
            end
        end
    end
    local gradle_stages, rust_stages = {}, {}
    for name, pkg in pairs(packages) do
        for target, this in pkg:each() do
            if is_android_gradle(target, pkg) then
                append(gradle_stages, target)
                target.pool = 'gradle_android'
            end
            if is_rust_toolchain(target, pkg) then
                append(rust_stages, target)
                target.pool = 'rust_toolchain'
            end
        end
    end
    assign_interactive(gradle_stages)
    assign_interactive(rust_stages)
    if ninja.supports_console_pool then
        for name, pkg in pairs(packages) do
            for target, this in pkg:each() do
                if is_interactive(target) then
                    target.pool = 'console'
                end
            end
        end
    end
end

function P.generate(out_file, rules)
    check_ninja_features()

    packages = rules
    local file = assert(io.open(out_file, 'w'))
    local sorted_rules = sort(table.tolist(rules),
        function (a, b)
            return a.name < b.name
        end)

    assign_pools(rules)

    local lines = {
        binding('ninja_required_version', '1.1'),
        binding('builddir', assert(Jagen.build_dir)),
        format_pool('gradle_android', 1),
        format_pool('rust_toolchain', 1),
        format_rule('stage', join {
                separated(Jagen.shell), 'jagen-stage $args'
            }),
        format_rule('refresh', join_space(nonempty { Jagen.shell, System.expand('$jagen_root_dir/jagen'), 'refresh' }))
    }

    local for_refresh = Jagen:find_for_refresh()
    local include_dir = System.expand(os.getenv('jagen_include_dir'))
    for pkg in each(sorted_rules) do
        append(for_refresh, System.mkpath(include_dir, string.format('%s.sh', pkg.name)))
        for name, config in pairs(pkg.configs) do
            append(for_refresh, System.mkpath(include_dir, string.format('%s:%s.sh', pkg.name, name)))
        end
    end
    append(lines, format_refresh(for_refresh, sorted_rules))
    append(lines, format_phony(for_refresh))

    extend(lines, pmap(format_package, sorted_rules))

    file:write(join_nl(lines))
    file:write('\n')

    file:close()
end

return P
