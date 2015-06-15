--{{{ common

function copy(t)
    local c = {}
    for k, v in pairs(t) do
        if type(v) == 'table' then
            v = copy(v)
        end
        c[k] = v
    end
    return c
end

function list(t)
    local o = {}
    for _, v in ipairs(t or {}) do
        table.insert(o, v)
    end
    return o
end

function append(...)
    local o = {}
    for _, arg in ipairs({...}) do
        for _, i in ipairs(arg) do
            table.insert(o, i)
        end
    end
    return o
end

function for_each(t, f)
    for _, v in ipairs(t or {}) do
        f(v)
    end
end

function map(f, t)
    local r = {}
    for i, v in ipairs(t or {}) do
        table.insert(r, f(v))
    end
    return r
end

function find(f, t)
    for _, v in ipairs(t or {}) do
        if f(v) then
            return v
        end
    end
    return nil
end

function filter(pred, list)
    local o = {}
    for _, v in ipairs(list or {}) do
        if pred(v) then
            table.insert(o, v)
        end
    end
    return o
end

function compose(f, g)
    return function (...)
        f(unpack(g(...)))
    end
end

local function find_by_name(name, list)
    local function by_name(x)
        return x.name == name
    end
    return find(by_name, list)
end

function string.split(s, sep)
    local o, b, e = {}
    local init = 1

    repeat
        b, e = string.find(s, sep, init, true)
        if not b then b = 0 end
        table.insert(o, string.sub(s, init, b-1))
        if e then init = e + 1 end
    until b == 0

    return o
end

function table.rest(t, start)
    local o = {}
    for i = start, #t do
        table.insert(o, t[i])
    end
    return o
end

--}}}
--{{{ system

local system = {}

function system.mkpath(...)
    local sep = '/'
    local path = {}
    for _, c in ipairs({...}) do
        table.insert(path, c)
    end
    return table.concat(path, sep)
end

function system.mkdir(pathname)
    system.exec('mkdir -p "' .. pathname .. '"')
end

function system.file_newer(file1, file2)
    local cmd = string.format('[ "%s" -nt "%s" ]', file1, file2)
    return os.execute(cmd) == 0
end

function system.file_older(file1, file2)
    local cmd = string.format('[ "%s" -ot "%s" ]', file1, file2)
    return os.execute(cmd) == 0
end

function system.exec(command, ...)
    local cmd = { command }
    for _, arg in ipairs({...}) do
        table.insert(cmd, string.format('%q', tostring(arg)))
    end
    local status = os.execute(table.concat(cmd, ' '))
    return status
end

--}}}
--{{{ format

local format = {}

function format.indent(n)
    local t = {}
    for i = 1, n do
        table.insert(t, " ")
    end
    return table.concat(t)
end

--}}}
--{{{ ninja

ninja = {}

function ninja:format_inputs(inputs)
    local sep = string.format(' $\n%s', format.indent(16))
    local t = {}
    for _, d in ipairs(inputs) do
        table.insert(t, tostring(d))
    end
    return table.concat(t, sep)
end

function ninja:generate(packages, out_file, in_file)
    local out = io.open(out_file, 'w')

    out:write(string.format('builddir = %s\n\n', os.getenv('pkg_build_dir')))
    out:write(string.format('rule command\n'))
    out:write(string.format('    command = $command\n\n'))
    out:write(string.format('rule script\n'))
    out:write(string.format('    command = ' .. os.getenv('pkg_bin_dir') .. '/$script && touch $out\n\n'))

    local sep = string.format(' $\n%s', format.indent(16))

    for i, pkg in ipairs(packages) do
        local pn = pkg.name
        for j, stage in ipairs(pkg.stages or {}) do
            local sn = stage.stage
            local sc = stage.config
            out:write(string.format('build %s: script', tostring(stage)))
            if #stage.inputs > 0 then
                out:write(' $\n' .. format.indent(16))
                out:write(ninja:format_inputs(stage.inputs))
            end
            out:write('\n')
            out:write(string.format('    script = jagen-pkg %s %s', pn, sn))
            if sc then
                out:write(' ', sc)
            end
            out:write('\n')
        end
        out:write("\n")
    end

    out:close()
end

--}}}
--{{{ target

target = { meta = {} }

function target.new(n, s, c)
    local t = { name = n, stage = s, config = c }
    setmetatable(t, target.meta)
    return t
end

function target.new_from_arg(arg)
    local name, stage, config
    local c = string.split(arg, ':')

    if c[1] and #c[1] > 0 then
        name = c[1]
    end
    if c[2] and #c[2] > 0 then
        stage = c[2]
    end
    if c[3] and #c[3] > 0 then
        config = c[3]
    end

    return target.new(name, stage, config)
end

function target.maybe_add_stage(t, stage)
    if not t.stage then
        t.stage = stage
    end
    return t
end

target.meta.__eq = function(a, b)
    return a.name == b.name and
    a.stage == b.stage and
    a.config == b.config
end

target.meta.__tostring = function(t)
    return table.concat({ t.name, t.stage, t.config }, '-')
end

--}}}
--{{{ jagen

jagen =
{
    debug = os.getenv('pkg_debug'),
    flags = os.getenv('pkg_flags'),
    sdk   = os.getenv('pkg_sdk'),

    bin_dir   = os.getenv('pkg_bin_dir'),
    lib_dir   = os.getenv('pkg_lib_dir'),
    src_dir   = os.getenv('pkg_src_dir'),
    build_dir = os.getenv('pkg_build_dir'),
}

function jagen.tostring(...)
    return table.concat(map(tostring, {...}), ' ')
end

function jagen.message(...)
    print(string.format('\027[1;34m:::\027[0m %s', jagen.tostring(...)))
end
function jagen.warning(...)
    print(string.format('\027[1;33m:::\027[0m %s', jagen.tostring(...)))
end
function jagen.error(...)
    print(string.format('\027[1;31m:::\027[0m %s', jagen.tostring(...)))
end
function jagen.debug(...)
    if jagen.debug then
        print(string.format('\027[1;36m:::\027[0m %s', jagen.tostring(...)))
    end
end
function jagen.debug1(...)
    if os.getenv('pkg_debug') >= '1' then
        print(string.format('\027[1;36m:::\027[0m %s', jagen.tostring(...)))
    end
end
function jagen.debug2(...)
    if os.getenv('pkg_debug') >= '2' then
        print(string.format('\027[1;36m:::\027[0m %s', jagen.tostring(...)))
    end
end

function jagen.flag(f)
    return false
end

function jagen.load_package(rule)
    jagen.debug2('load package: '..rule.name)
    local stages = {}
    for i, s in ipairs(rule) do
        table.insert(stages, s)
        rule[i] = nil
    end
    rule.stages = stages
    return rule
end

function jagen.load_rules()
    assert(jagen.sdk)

    local filename = system.mkpath(jagen.lib_dir, 'rules.'..jagen.sdk..'.lua')
    local rules = dofile(filename)

    local function load_package(pkg_rule)
        local package = {}
        local tmp = {}
        local collected = {}

        local function load_source(source)
            if type(source) == 'string' then
                return { type = 'dist', location = source }
            else
                return source
            end
        end

        local function getkey(name, config)
            if config then
                return name .. ':' .. config
            else
                return name
            end
        end

        local function input_to_target(d)
            return target.new(d[1], d[2], d[3])
        end

        local function load_stage(stage_rule)
            local stage, config

            if type(stage_rule[1]) == 'string' then
                stage = stage_rule[1]
                table.remove(stage_rule, 1)
            end
            if type(stage_rule[1]) == 'string' then
                config = stage_rule[1]
                table.remove(stage_rule, 1)
            end

            local key = getkey(stage, config)
            local inputs = map(input_to_target, list(stage_rule))
            
            if tmp[key] then
                tmp[key].inputs = append(tmp[key].inputs or {}, inputs)
            else
                local target = target.new(pkg_rule.name, stage, config)
                target.inputs = inputs
                tmp[key] = target
                table.insert(collected, target)
            end
        end

        function add_previous(stages)
            local prev, common

            for _, s in ipairs(stages) do
                if prev then
                    if common and s.config ~= prev.config then
                        table.insert(s.inputs, 1, common)
                    else
                        table.insert(s.inputs, 1, prev)
                    end
                end

                prev = s
                if not s.config then
                    common = s
                end
            end
        end

        for_each(pkg_rule.stages, load_stage)
        add_previous(collected)

        package.name = pkg_rule.name
        package.source = load_source(pkg_rule.source)
        package.patches = pkg_rule.patches
        package.stages = collected

        return package
    end

    local packages = map(load_package, rules)

    for _, pkg in ipairs(packages) do
        packages[pkg.name] = pkg
    end

    return packages
end

function jagen.generate_include_script(pkg)
    local name = pkg.name
    local dir = os.getenv('pkg_build_include_dir')
    local filename = system.mkpath(dir, name .. '.sh')

    local function source(pkg)
        local o = {}
        local s = pkg.source
        if s then
            if s.type == 'git' or s.type == 'hg' then
                table.insert(o, s.type)
                table.insert(o, s.location)
            elseif s.type == 'dist' then
                table.insert(o, system.mkpath('$pkg_dist_dir', s.location))
            end
        end
        return string.format('p_source="%s"\n', table.concat(o, ' '))
    end

    local function patches(pkg)
        local o = {}
        table.insert(o, 'pkg_patch_pre() {')
        for _, patch in ipairs(pkg.patches or {}) do
            local name = patch[1]
            local strip = patch[2]
            table.insert(o, string.format('  p_patch %d "%s"', strip, name))
        end
        table.insert(o, '}')
        return table.concat(o, '\n')
    end

    system.mkdir(dir)

    local f = assert(io.open(filename, 'w+'))
    f:write('#!/bin/sh\n')
    f:write(source(pkg))
    if pkg.patches then
        f:write(patches(pkg))
    end
    f:close()
end

--}}}
--{{{ pkg

local pkg = {}

function pkg.filter(pkg, target)
    local function match_config(a, b)
        return not a.config or a.config == b.config
    end
    local function match_stage(a, b)
        return not a.stage or a.stage == b.stage
    end
    local function match_target(stage)
        return match_stage(target, stage) and match_config(target, stage)
    end
    return pkg and filter(match_target, pkg.stages) or {}
end

--}}}
--{{{ build

local build = {}

build.wrapper = system.mkpath(jagen.lib_dir, 'build.sh')

function build.find_targets(packages, arg)
    local t = target.new_from_arg(arg)
    local targets = pkg.filter(packages[t.name], t)
    if #targets == 0 then
        jagen.warning('No matching targets found for:', arg)
        return {}
    end
    return targets
end

function jagen.build(args)
    local packages = jagen.load_rules()
    local targets = {}

    for _, arg in ipairs(args) do
        targets = append(targets, build.find_targets(packages, arg))
    end

    return system.exec(build.wrapper, 'build', unpack(targets))
end

function jagen.rebuild(args)
    local packages = jagen.load_rules()
    local targets = {}

    for _, arg in ipairs(args) do
        targets = append(targets, build.find_targets(packages, arg))
    end

    return system.exec(build.wrapper, 'rebuild', unpack(targets))
end

---}}}

command = arg[1]

if command == 'generate' then
    local build_file = arg[2]
    local rules_file = arg[3]

    if system.file_older(build_file, rules_file) or jagen.debug then
        jagen.message("Generating build rules")
        local packages = jagen.load_rules()
        ninja:generate(packages, arg[2], arg[3])
        for_each(packages, jagen.generate_include_script)
    end
elseif command == 'build' then
    local build_file = arg[2]
    local args = table.rest(arg, 3)

    return jagen.build(args)
elseif command == 'rebuild' then
    local build_file = arg[2]
    local args = table.rest(arg, 3)

    return jagen.rebuild(args)
else
    jagen.error('Unknown command:', command)
end
