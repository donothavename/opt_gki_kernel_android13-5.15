update_clang() {
    local common_dir clang_ver
    common_dir="$(abk_common_dir)"

    abk_require_file "$common_dir/Makefile"
    abk_require_file "$common_dir/build.config.constants"

    sed -i 's/CLANG_VERSION=.*/CLANG_VERSION=r584948c/' "$common_dir/build.config.constants"
    sed -i 's/		   -std=gnu89/		   -std=gnu89 \\\n		   -Wno-default-const-init-var-unsafe \\\n		   -Wno-default-const-init-field-unsafe \\\n		   -Wno-uninitialized-const-pointer/' "$common_dir/Makefile"

    abk_log "更新 clang，拉取 main-kernel-2026 分支"

    cd "$KERNEL_ROOT/prebuilts/clang/host"
    rm -r linux-x86/
    git clone -b main-kernel-2026 https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86 --depth=1
}