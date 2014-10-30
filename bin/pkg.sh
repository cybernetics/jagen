#!/bin/sh

if [ -z "$ja_root" ]; then
    export ja_root="$(realpath $(dirname $0)/..)"
fi

. "$ja_root/lib/env.sh" || exit
. "$ja_root/lib/pkg.sh" || exit

. "$ja_lib_dir/env/cmake.sh" || exit

include "$ja_lib_dir/env/sdk"

p_build_root="$ja_build_dir/pkg"

p_name="$1"
p_stage="$2"
p_config="$3"

p_log="${ja_build_dir}/${p_name}-${p_stage}${p_config:+-${p_config}}.log"
p_work_dir="$p_build_root/$p_name"

include "$ja_lib_dir/pkg/$p_name" 

if [ -z "$p_source_dir" ]; then
    p_source_name=$(basename "$p_source" \
        | sed -r 's/\.t(ar\.)?(gz|bz2|xz)//')
    p_source_dir="$p_work_dir/$p_source_name"
fi

if [ -z "$p_build_dir" ]; then
    p_build_dir="${p_work_dir}${p_config:+/$p_config}"
fi

rm -f "$p_log" || exit

if [ ! -d "$p_build_dir" ]; then
    p_run mkdir -p "$p_build_dir"
fi

p_run cd "$p_build_dir"

p_stage_function="pkg_${p_stage}"

if [ "$p_config" ]; then
    use_env "$p_config"
    p_stage_function="${p_stage_function}_${p_config}"
fi

eval "$p_stage_function" || \
    die "Failed to run '$p_stage' stage of package $p_name${p_config:+ ($p_config)}"
