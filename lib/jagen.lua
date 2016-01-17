--{{{ common

function copy(o)
    if type(o) == 'table' then
        local c = {}
        for k, v in pairs(o) do
            c[k] = copy(v)
        end
        return c
    else
        return o
    end
end

function each(a)
    local i, n = 0, #a
    return function (t)
        i = i + 1
        if i <= n then return t[i] end
    end, a
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

function map(f, t)
    local r = {}
    for i, v in ipairs(t or {}) do
        table.insert(r, f(v))
    end
    return r
end

function find(pred, list)
    for i, v in ipairs(list) do
        if pred(v) then
            return v, i
        end
    end
    return nil, nil
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

function table.merge(a, b)
    for k, v in pairs(b) do
        if type(k) ~= 'number' then
            if type(v) == 'table' then
                a[k] = table.merge(a[k] or {}, v)
            else
                a[k] = v
            end
        end
    end
    for _, v in ipairs(b) do
        table.insert(a, v)
    end
    return a
end

function table.dump(t, i)
    local i = i or 0
    if type(t) ~= 'table' then
        io.write(tostring(t), '\n')
        return
    end
    io.write(string.rep(' ', i), tostring(t), ' {\n')
    for k, v in pairs(t) do
        io.write(string.rep(' ', i+2), k, ' = ')
        if type(v) == 'table' then
            io.write('\n')
            table.dump(v, i+4)
        else
            io.write(tostring(v), '\n')
        end
    end
    io.write(string.rep(' ', i), '}\n')
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

function system.tocommand(...)
    local command = {}
    for _, arg in ipairs({...}) do
        table.insert(command, string.format('%s', tostring(arg)))
    end
    return table.concat(command, ' ')
end

function system.exec(...)
    local command = system.tocommand(...)
    jagen.debug1(command)
    local status = os.execute(command)
    return status == 0, status % 0xFF
end

function system.popen(...)
    local command = system.tocommand(...)
    jagen.debug1(command)
    return io.popen(command)
end

function system.exists(pathname)
    assert(type(pathname) == 'string')
    return os.execute(string.format('test -e "%s"', pathname)) == 0
end

--}}}
--{{{ Target

Target = {}
Target.__index = Target

function Target:new(name, stage, config)
    local target = {
        name   = name,
        stage  = stage,
        config = config,
        inputs = {}
    }
    setmetatable(target, self)
    return target
end

function Target:from_rule(rule, name, config)
    local stage = rule[1]; assert(type(stage) == 'string')
    local target = Target:new(name, stage, config)

    for i = 2, #rule do
        local input = rule[i]
        table.insert(target.inputs, Target:new(input[1], input[2], input[3]))
    end

    return target
end

function Target:from_arg(arg)
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

    return Target:new(name, stage, config)
end

function Target:__eq(other)
    return self.name   == other.name   and
           self.stage  == other.stage  and
           self.config == other.config
end

function Target:__tostring(sep)
    local o = {}
    sep = sep or '-'
    if self.name   then table.insert(o, self.name)   end
    if self.stage  then table.insert(o, self.stage)  end
    if self.config then table.insert(o, self.config) end
    return table.concat(o, sep)
end

function Target:add_inputs(target)
    for _, i in ipairs(target.inputs) do
        local function eq(t)
            return t == i
        end
        local found = find(eq, self.inputs)
        if not found then
            table.insert(self.inputs, i)
        end
    end

    return self
end

--}}}
--{{{ Package

Package = {
    init_stages = { 'unpack', 'patch' }
}
Package.__index = Package

function Package:__tostring()
    local o = {}
    if self.name then table.insert(o, self.name) end
    if self.config then table.insert(o, self.config) end
    return table.concat(o, ':')
end

function Package:read(rule)
    if type(rule[1]) == 'string' then
        rule.name = rule[1]
        table.remove(rule, 1)
    end
    if type(rule[1]) == 'string' then
        rule.config = rule[1]
        table.remove(rule, 1)
    end
    if type(rule.source) == 'string' then
        rule.source = { type = 'dist', location = rule.source }
    end
    return rule
end

function Package:load(filename)
    local pkg = {}
    local env = {}
    function env.package(rule)
        pkg = Package:read(rule)
    end
    local chunk = loadfile(filename)
    if chunk then
        setfenv(chunk, env)
        chunk()
    end
    return pkg
end

function Package:create(name)
    local pkg = { name = name, stages = {} }
    setmetatable(pkg, self)
    self.__index = self

    for _, s in ipairs(self.init_stages) do
        pkg:add_target(Target:new(name, s))
    end

    for filename in each(jagen.import_paths('pkg/'..name..'.lua')) do
        table.merge(pkg, pkg:load(filename))
    end

    return pkg
end

function Package:add_target(target)
    local function default(this)
        for _, stage in ipairs(self.init_stages) do
            if stage == target.stage and stage == this.stage then
                return this
            end
        end
    end
    local function eq(this)
        return this == target or default(this)
    end

    local found = find(eq, self.stages)
    if found then
        jagen.debug2(tostring(self), '=', tostring(target))
        found:add_inputs(target)
        return self
    else
        jagen.debug2(tostring(self), '+', tostring(target))
        table.insert(self.stages, target)
    end

    return self
end

function Package:add_build_targets(config)
    local build = self.build
    if build then
        if build.type == 'GNU' and build.autoreconf then
            self:add_target(Target:from_rule({ 'autoreconf',
                        { 'libtool', 'install', 'host' }
                }, self.name))
        end
        if build.type ~= 'manual' then
            if config == 'target' then
                self:add_target(Target:from_rule({ 'build',
                            { 'toolchain', 'install', 'target' }
                    }, self.name, config))
            else
                self:add_target(Target:from_rule({ 'build',
                    }, self.name, config))
            end
            self:add_target(Target:from_rule({ 'install'
                }, self.name, config))
        end
    end
end

function Package:add_ordering_dependencies()
    local prev, common

    for _, s in ipairs(self.stages) do
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

--}}}
--{{{ Source

Source = {}

function Source:is_scm()
    return self.type == 'git' or self.type == 'hg' or self.type == 'repo'
end

function Source:basename(filename)
    local name = string.match(filename, '^.*/(.+)') or filename
    local exts = { '%.git', '%.tar', '%.tgz', '%.txz', '%.tbz2',
        '%.zip', '%.rar', ''
    }
    for _, ext in ipairs(exts) do
        local match = string.match(name, '^([%w_.-]+)'..ext)
        if match then
            return match
        end
    end
end

function Source:create(source)
    local source = source or {}

    if source.type == 'git' then
        source = GitSource:new(source)
    elseif source.type == 'hg' then
        source = HgSource:new(source)
    elseif source.type == 'repo' then
        source = RepoSource:new(source)
    elseif source.type == 'dist' then
        source.location = '$jagen_dist_dir/'..source.location
        source = Source:new(source)
    else
        source = Source:new(source)
    end

    if source.location then
        local dir = source:is_scm() and '$jagen_src_dir' or '$pkg_work_dir'
        local basename = source:basename(source.location)
        source.path = system.mkpath(dir, source.path or basename)
    end

    return source
end

function Source:new(o)
    local o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

GitSource = Source:new()

function GitSource:new(o)
    local source = Source.new(GitSource, o)
    source.branch = source.branch or 'master'
    return source
end

function GitSource:exec(...)
    return system.exec('git', '-C', assert(self.path), ...)
end

function GitSource:popen(...)
    return system.popen('git', '-C', assert(self.path), ...):read()
end

function GitSource:head()
    return self:popen('rev-parse', 'HEAD')
end

function GitSource:dirty()
    return self:popen('status', '--porcelain')
end

function GitSource:clean()
    return self:exec('checkout', 'HEAD', '.') and self:exec('clean', '-fxd')
end

function GitSource:fetch(branch)
    local cmd = { 'fetch', '--prune', '--no-tags', 'origin' }
    if branch then
        local src = 'refs/heads/'..branch
        local dst = 'refs/remotes/origin/'..branch
        table.insert(cmd, '+'..src..':'..dst)
    end
    return self:exec(unpack(cmd))
end

function GitSource:checkout(branch)
    assert(branch)
    local name = self:popen('branch', '--list', branch)
    if name and #name > 0 then
        if string.sub(name, 1, 1) == '*' then
            return true
        else
            return self:exec('checkout', branch)
        end
    else
        local add = { 'remote', 'set-branches', '--add', 'origin', branch }
        local checkout = { 'checkout', '-b', branch, '-t', 'origin/'..branch }
        return self:exec(unpack(add)) and self:exec(unpack(checkout))
    end
end

function GitSource:merge(branch)
    return self:exec('merge', '--ff-only', 'origin/'..assert(branch))
end

function GitSource:update()
    local branch = assert(self.branch)
    return self:fetch(branch) and self:checkout(branch) and self:merge(branch)
end

function GitSource:clone()
    return system.exec('git', 'clone', '--branch', assert(self.branch),
        '--depth', 1, assert(self.location), assert(self.path))
end

HgSource = Source:new()

function HgSource:new(o)
    local source = Source.new(HgSource, o)
    source.branch = source.branch or 'default'
    return source
end

function HgSource:exec(...)
    return system.exec('hg', '-R', assert(self.path), ...)
end

function HgSource:popen(...)
    return system.popen('hg', '-R', assert(self.path), ...):read()
end

function HgSource:head()
    return self:popen('id', '-i')
end

function HgSource:dirty()
    return self:popen('status')
end

function HgSource:clean()
    return self:exec('update', '-C') and self:exec('purge', '--all')
end

function HgSource:update()
    local pull = { 'pull', '-r', assert(self.branch) }
    local update = { 'update', '-r', assert(self.branch) }
    return self:exec(unpack(pull)) and self:exec(unpack(update))
end

function HgSource:clone()
    return system.exec('hg', 'clone', '-r', assert(self.branch),
        assert(self.location), assert(self.path))
end

RepoSource = Source:new()

function RepoSource:new(o)
    local source = Source.new(RepoSource, o)
    source.jobs = jagen.nproc * 2
    return source
end

function RepoSource:exec(...)
    local cmd = { 'cd', '"'..assert(self.path)..'"', '&&', 'repo', ... }
    return system.exec(unpack(cmd))
end

function RepoSource:popen(...)
    local cmd = { 'cd', '"'..assert(self.path)..'"', '&&', 'repo', ... }
    return system.popen(unpack(cmd))
end

function RepoSource:load_projects(...)
    local o = {}
    local list = self:popen('list', ...)
    while true do
        local line = list:read()
        if not line then break end
        local path, name = string.match(line, "(.+)%s:%s(.+)")
        if name then
            o[name] = path
        end
    end
    return o
end

function RepoSource:head()
    return self:popen('status', '-j', 1, '--orphans'):read('*all')
end

function RepoSource:dirty()
    return false
end

function RepoSource:clean()
    local projects = self:load_projects()
    local function is_empty(path)
        return system.popen('cd', '"'..path..'"', '&&', 'echo', '*'):read() == '*'
    end
    for n, p in pairs(projects) do
        local path = system.mkpath(self.path, p)
        if not is_empty(path) then
            if not system.exec('git', '-C', path, 'checkout', 'HEAD', '.') then
                return false
            end
            if not system.exec('git', '-C', path, 'clean', '-fxd') then
                return false
            end
        end
    end
    return true
end

function RepoSource:update()
    local cmd = { 'sync', '-j', self.jobs, '--current-branch', '--no-tags',
        '--optimized-fetch'
    }
    return self:exec(unpack(cmd))
end

function RepoSource:clone()
    local mkdir = { 'mkdir -p "'..self.path..'"' }
    local init = { 'init', '-u', assert(self.location),
        '-b', assert(self.branch), '-p', 'linux', '--depth', 1
    }
    return system.exec(unpack(mkdir)) and self:exec(unpack(init)) and self:update()
end

--}}}
--{{{ Ninja

Ninja = {
    space = 4
}

function Ninja:new()
    local o = {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function Ninja:indent(level)
    level = level or 0
    local t = {}
    for i = 1, level * self.space do
        table.insert(t, ' ')
    end
    return table.concat(t)
end

function Ninja:variable(k, v, level)
    return string.format('%s%s = %s\n', self:indent(level), k, v)
end

function Ninja:rule(rule)
    local o = {
        string.format('rule %s', rule.name),
        self:variable('command', rule.command, 1)
    }
    if rule.variables then
        for k, v in pairs(rule.variables) do
            table.insert(o, self:variable(k, v, 1))
        end
    end
    return table.concat(o, '\n')
end

function Ninja:build(build)
    local header = {
        string.format('build %s: %s',
            table.concat(build.outputs, ' '), build.rule),
        unpack(map(tostring, build.inputs))
    }
    local o = {
        table.concat(header, ' $\n'..self:indent(4))
    }
    if build.variables then
        for k, v in pairs(build.variables) do
            table.insert(o, self:variable(k, v, 1))
        end
    end
    return table.concat(o, '\n')
end

function Ninja:header()
    local o = {
        self:variable('builddir', jagen.build_dir),
        self:rule({
                name    = 'command',
                command = '$command'
            }),
        self:rule({
                name    = 'script',
                command = '$script && touch $out'
            }),
    }
    return table.concat(o)
end

function Ninja:build_stage(target)
    local shell = jagen.shell
    local script = 'jagen-pkg '..target:__tostring(' ')
    if shell and #shell > 0 then
        script = shell.." "..script
    end
    return self:build({
            rule      = 'script',
            outputs   = { tostring(target) },
            inputs    = target.inputs,
            variables = { script = script }
        })
end

function Ninja:build_package(pkg)
    local o = {}
    for _, stage in ipairs(pkg.stages) do
        table.insert(o, self:build_stage(stage))
    end
    return table.concat(o)
end

function Ninja:generate(out_file, packages)
    local out = io.open(out_file, 'w')

    out:write(self:header())
    out:write('\n')
    for _, pkg in ipairs(packages) do
        out:write(self:build_package(pkg))
        out:write('\n')
    end

    out:close()
end

--}}}
--{{{ jagen

jagen =
{
    dir  = os.getenv('jagen_dir'),
    root = os.getenv('jagen_root'),

    overlays = os.getenv('jagen_overlays'),

    shell = os.getenv('jagen_shell'),

    debug = os.getenv('jagen_debug'),
    flags = os.getenv('jagen_flags'),

    lib_dir     = os.getenv('jagen_lib_dir'),
    src_dir     = os.getenv('jagen_src_dir'),
    build_dir   = os.getenv('jagen_build_dir'),
    include_dir = os.getenv('jagen_include_dir'),

    patch_dir   = os.getenv('jagen_patch_dir'),
    private_dir = os.getenv('jagen_private_dir'),

    nproc = assert(tonumber(io.popen('nproc'):read()))
}

jagen.cmd = system.mkpath(jagen.lib_dir, 'cmd.sh')
jagen.build_file = system.mkpath(jagen.build_dir, 'build.ninja')

function jagen.message(...)
    io.write('(I) ', string.format(...), '\n')
    io.flush()
end

function jagen.warning(...)
    io.stderr:write('(W) ', string.format(...), '\n')
    io.stderr:flush()
end

function jagen.error(...)
    io.stderr:write('(E) ', string.format(...), '\n')
    io.stderr:flush()
end

function jagen.debug0(...)
    if jagen.debug then
        io.write('(D) ', string.format(...), '\n')
        io.flush()
    end
end

function jagen.debug1(...)
    if jagen.debug >= '1' then
        io.write('(D) ', string.format(...), '\n')
        io.flush()
    end
end

function jagen.debug2(...)
    if jagen.debug >= '2' then
        io.write('(D) ', string.format(...), '\n')
        io.flush()
    end
end

function jagen.die(...)
    jagen.error(...)
    os.exit(1)
end

function jagen.flag(f)
    for w in string.gmatch(jagen.flags, "[_%w]+") do
        if w == f then
            return true
        end
    end
    return false
end

function jagen.import_paths(filename)
    local o = {}
    table.insert(o, system.mkpath(jagen.dir, 'lib', filename))
    for _, overlay in ipairs(string.split(jagen.overlays, ' ')) do
        table.insert(o, system.mkpath(jagen.dir, 'overlay', overlay, filename))
    end
    table.insert(o, system.mkpath(jagen.root, filename))
    return o
end

function jagen.load(filename)
    local rules = {}
    local env = {
        table = table,
        jagen = jagen
    }
    function env.package(rule)
        table.insert(rules, Package:read(rule))
    end
    local chunk = loadfile(filename)
    if chunk then
        setfenv(chunk, env)
        chunk()
    end
    return rules
end

function jagen.rules(path)
    local function genrules(suffix)
        for _, file in ipairs(jagen.import_paths(suffix)) do
            for _, rule in ipairs(jagen.load(file)) do
                coroutine.yield(rule)
            end
        end
    end
    return coroutine.wrap(genrules), path..'.lua'
end

function jagen.load_rules()
    local packages = {}

    for rule in jagen.rules('rules') do
        local name = assert(rule.name)
        local pkg = packages[name]
        if not pkg then
            pkg = Package:create(name)
            packages[name] = pkg
            table.insert(packages, pkg)
        end
        table.merge(pkg, rule)
        pkg:add_build_targets(rule.config)
        for stage in each(rule) do
            pkg:add_target(Target:from_rule(stage, pkg.name, rule.config))
        end
    end

    local libtool = Package:create('libtool')
    libtool:add_target(Target:new(libtool.name, 'build', 'host'))
    libtool:add_target(Target:new(libtool.name, 'install', 'host'))
    table.insert(packages, libtool)

    local tc = Package:create('toolchain')
    tc:add_target(Target:new(tc.name, 'install', 'target'))
    table.insert(packages, tc)

    for _, pkg in ipairs(packages) do
        pkg:add_ordering_dependencies()
        pkg.source = Source:create(pkg.source)
    end

    return packages
end

function jagen.generate_include_script(pkg)
    local name     = pkg.name
    local filename = name..'.sh'
    local path     = system.mkpath(jagen.include_dir, filename)
    local script   = Script:new(pkg)

    local f = assert(io.open(path, 'w+'))
    f:write(tostring(script))
    f:close()
end

function jagen.generate()
    local packages = jagen.load_rules()
    local ninja = Ninja:new()

    table.sort(packages, function (a, b)
            return a.name < b.name
        end)

    for _, pkg in ipairs(packages) do
        for _, stage in ipairs(pkg.stages) do
            table.sort(stage.inputs, function (a, b)
                    return tostring(a) < tostring(b)
                end)
        end
    end

    ninja:generate(jagen.build_file, packages)

    for _, package in ipairs(packages) do
        jagen.generate_include_script(package)
    end
end

--}}}
--{{{ script

Script = {}

function Script:new(pkg)
    local script = { pkg = pkg }
    setmetatable(script, self)
    self.__index = self
    return script
end

function Script:__tostring()
    local script = {
        self:header()
    }
    if self.pkg.source then
        table.insert(script, self:source())
    end
    table.insert(script, self:build())
    if self.pkg.patches then
        table.insert(script, self:patch())
    end

    return table.concat(script, '\n\n')
end

function Script:header()
    return '#!/bin/sh'
end

function Script:source()
    local pkg = self.pkg
    local source = pkg.source
    local o = {}
    if source.type and source.location then
        table.insert(o, string.format(
            'pkg_source="%s %s"', source.type, source.location))
    end
    if source.branch then
        table.insert(o, string.format('pkg_source_branch="%s"', source.branch))
    end
    if source.path then
        table.insert(o, string.format('pkg_source_dir="%s"', source.path))
    end
    return table.concat(o, '\n')
end

function Script:build()
    local o = {}
    local pkg = self.pkg
    local build_dir

    if pkg.build then
        local build = pkg.build

        if build.options then
            table.insert(o, string.format('pkg_options=\'%s\'', build.options))
        end
        if build.libs then
            table.insert(o, string.format("pkg_libs='%s'",
                table.concat(build.libs, ' ')))
        end
        if build.in_source then
            build_dir = '$pkg_source_dir'
        end
        if build.directory then
            build_dir = build.directory
        end
    end

    build_dir = build_dir or '$pkg_work_dir${pkg_config:+/$pkg_config}'

    table.insert(o, string.format('pkg_build_dir="%s"', build_dir))

    return table.concat(o, '\n')
end

function Script:patch()
    local o = {}
    table.insert(o, 'jagen_pkg_apply_patches() {')
    table.insert(o, '  pkg_run cd "$pkg_source_dir"')
    for _, patch in ipairs(self.pkg.patches or {}) do
        local name = patch[1]
        local strip = patch[2]
        table.insert(o, string.format('  pkg_run_patch %d "%s"', strip, name))
    end
    table.insert(o, '}')
    return table.concat(o, '\n')
end

--}}}
--{{{ build

local build = {}

function build.find_targets(packages, arg)
    local targets = {}
    local args = {}

    local function is_param(arg)
        return string.sub(arg, 1, 1) == '-'
    end
    local function match_config(a, b)
        return not a.config or a.config == b.config
    end
    local function match_stage(a, b)
        return not a.stage or a.stage == b.stage
    end
    local function match_target(target, stage)
        return match_stage(target, stage) and match_config(target, stage)
    end

    if is_param(arg) then
        table.insert(args, arg)
    else
        local target = Target:from_arg(arg)
        local packages = target.name and { packages[target.name] } or packages
        for _, pkg in ipairs(packages) do
            for _, stage in ipairs(pkg.stages) do
                if match_target(target, stage) then
                    table.insert(targets, stage)
                end
            end
        end
        if #targets == 0 then
            table.insert(args, arg)
        end
    end

    return targets, args
end

function jagen.build(args)
    local packages = jagen.load_rules()
    local targets = {}

    for _, arg in ipairs(args) do
        targets = append(targets, build.find_targets(packages, arg))
    end

    return system.exec(jagen.cmd, 'build', unpack(targets))
end

function jagen.rebuild(args)
    local packages = jagen.load_rules()
    local targets = {}

    for _, arg in ipairs(args) do
        targets = append(targets, build.find_targets(packages, arg))
    end

    return system.exec(jagen.cmd, 'rebuild', unpack(targets))
end

---}}}
--{{{ SourceManager

SourceManager = {}

function SourceManager:new(o)
    local o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function SourceManager:packages(names)
    local packages, scm_packages = jagen.load_rules(), {}
    if names and #names > 0 then
        for _, name in ipairs(names) do
            if not packages[name] then
                jagen.die('no such package: %s', name)
            end
            if not packages[name].source:is_scm() then
                jagen.die('not scm package: %s', name)
            end
            table.insert(scm_packages, packages[name])
        end
    else
        for _, pkg in ipairs(packages) do
            if pkg.source:is_scm() then
                table.insert(scm_packages, pkg)
            end
        end
    end
    return scm_packages
end

-- Should return 0 if true, 1 if false, for shell scripting.
function SourceManager:dirty_command(names)
    for _, pkg in ipairs(self:packages(names)) do
        if pkg.source:dirty() then
            return 0
        end
    end
    return 1
end

function SourceManager:status_command(names)
    for _, pkg in ipairs(self:packages(names)) do
        local source = pkg.source
        if system.exists(source.path) then
            local dirty = source:dirty() and 'dirty' or ''
            local head = source:head()
            if not head then
                jagen.die('failed to get source head for %s in %s',
                    pkg.name, source.path)
            end
            print(string.format("%s (%s): %s %s", pkg.name, source.location, head, dirty))
        else
            print(string.format("%s (%s): not exists", pkg.name, source.location))
        end
    end
end

function SourceManager:clean_command(names)
    for _, pkg in ipairs(self:packages(names)) do
        if not pkg.source:clean() then
            jagen.die('failed to clean %s (%s) in %s',
                pkg.name, pkg.source.branch, pkg.source.path)
        end
    end
end

function SourceManager:update_command(names)
    for _, pkg in ipairs(self:packages(names)) do
        if not pkg.source:update() then
            jagen.die('failed to update %s to the latest %s in %s',
                pkg.name, pkg.source.branch, pkg.source.path)
        end
    end
end

function SourceManager:clone_command(names)
    for _, pkg in ipairs(self:packages(names)) do
        if not pkg.source:clone() then
            jagen.die('failed to clone %s from %s to %s',
                pkg.name, pkg.source.location, pkg.source.path)
        end
    end
end

function SourceManager:delete_command(names)
    for _, pkg in ipairs(self:packages(names)) do
        if system.exists(pkg.source.path) then
            if not system.exec('rm', '-rf', pkg.source.path) then
                jagen.die('failed to delete %s source directory %s',
                    pkg.name, pkg.source.path)
            end
        end
    end
end

--}}}

command = arg[1]
status = 0

if command == 'refresh' then
    jagen.generate()
elseif command == 'build' then
    local args = table.rest(arg, 2)

    _, status = jagen.build(args)
elseif command == 'rebuild' then
    local args = table.rest(arg, 2)

    _, status = jagen.rebuild(args)
elseif command == 'src' then
    local subcommand = arg[2]
    local args = table.rest(arg, 3)
    local src = SourceManager:new()

    if not subcommand then
        jagen.die('no src subcommand specified')
    end

    if src[subcommand..'_command'] then
        status = src[subcommand..'_command'](src, args)
    else
        jagen.die('unknown src subcommand: %s', subcommand)
    end
else
    jagen.die('Unknown command: %s', command)
end

os.exit((status or 0) % 0xFF)
