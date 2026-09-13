update_clang() {
    local common_dir clang_ver
    common_dir="$(abk_common_dir)"

    abk_require_file "$common_dir/Makefile"
    abk_require_file "$common_dir/build.config.constants"

    sed -i 's/CLANG_VERSION=.*/CLANG_VERSION=r614150/' "$common_dir/build.config.constants"
    sed -i 's/\t\t   -std=gnu89/\t\t   -std=gnu89 \\\n\t\t   -Wno-default-const-init-var-unsafe \\\n\t\t   -Wno-default-const-init-field-unsafe \\\n\t\t   -Wno-uninitialized-const-pointer/' "$common_dir/Makefile"

    abk_log "更新 clang，拉取 main-kernel 分支"

    cd "$KERNEL_ROOT/prebuilts/clang/host"
    rm -r linux-x86/
    git clone --filter=blob:none --no-checkout --depth=1  -b main-kernel https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86
    cd linux-x86
    git sparse-checkout init --no-cone
    echo '/*\n!/clang-*/\n/clang-r614150/' > ".git/info/sparse-checkout"
    git checkout
}