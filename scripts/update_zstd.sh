#!/usr/bin/env bash

update_zstd_files() {
    local common_dir
    common_dir="$(abk_common_dir)"

    abk_log "移除旧版本 ZSTD 文件……"
    rm -rf "$common_dir/lib/zstd/.*"
    rm "$common_dir/crypto/zstd.c" "$common_dir/fs/btrfs/zstd.c" "$common_dir/fs/squashfs/zstd_wrapper.c"
    find "$common_dir/include/linux" -name "zstd*.h" | xargs -I {} rm {}

    abk_log "复制新版本 ZSTD 文件……"
    abk_copy_into_kernel "$MODULE_DIR/files/zstd/." "common"
}

patch_zstd_lib_kconfig() {
    local common_dir
    common_dir="$(abk_common_dir)"

    abk_require_file "$common_dir/lib/Kconfig"

    abk_log "修补 lib/Kconfig"
    perl -0777 -pi -e 's/config\s+ZSTD_COMPRESS\s+select\s+XXHASH\s+tristate\s+config\s+ZSTD_DECOMPRESS\s+select\s+XXHASH\s+tristate/config ZSTD_COMMON\n	select XXHASH\n	tristate\n\nconfig ZSTD_COMPRESS\n	select ZSTD_COMMON\n	tristate\n\nconfig ZSTD_DECOMPRESS\n	select ZSTD_COMMON\n	tristate/gs' "$common_dir/lib/Kconfig"
}

patch_zstd_fun_name() {
    local common_dir
    common_dir="$(abk_common_dir)"

    abk_require_file "$common_dir/fs/f2fs/super.c"
    abk_require_file "$common_dir/fs/f2fs/compress.c"
    abk_require_file "$common_dir/fs/pstore/platform.c"
    abk_require_file "$common_dir/fs/incfs/data_mgmt.c"
    
    abk_log "修补 ZSTD 方法名"

    sed -i 's/ZSTD_compressBound/zstd_compress_bound/g' "$common_dir/fs/pstore/platform.c"

    sed -i 's/ZSTD_DStreamWorkspaceBound/zstd_dstream_workspace_bound/g' "$common_dir/fs/incfs/data_mgmt.c"
    sed -i 's/ZSTD_initDStream/zstd_init_dstream/g' "$common_dir/fs/incfs/data_mgmt.c"

    sed -i 's/ZSTD_maxCLevel/zstd_max_clevel/g' "$common_dir/fs/f2fs/super.c"

    sed -i 's/ZSTD_parameters/zstd_parameters/g' "$common_dir/fs/f2fs/compress.c"
    sed -i 's/ZSTD_CStreamWorkspaceBound/zstd_cstream_workspace_bound/g' "$common_dir/fs/f2fs/compress.c"
    sed -i 's/ZSTD_CStream/zstd_cstream/g' "$common_dir/fs/f2fs/compress.c"
    sed -i 's/ZSTD_getParams(level, cc->rlen, 0)/zstd_get_params(level, cc->rlen)/g' "$common_dir/fs/f2fs/compress.c"
    sed -i 's/ZSTD_initCStream/zstd_init_cstream/g' "$common_dir/fs/f2fs/compress.c"
    sed -i 's/ZSTD_inBuffer/zstd_in_buffer/g' "$common_dir/fs/f2fs/compress.c"
    sed -i 's/ZSTD_outBuffer/zstd_out_buffer/g' "$common_dir/fs/f2fs/compress.c"
    sed -i 's/ZSTD_compressStream/zstd_compress_stream/g' "$common_dir/fs/f2fs/compress.c"
    sed -i 's/ZSTD_isError/zstd_is_error/g' "$common_dir/fs/f2fs/compress.c"
    sed -i 's/ZSTD_getErrorCode/zstd_get_error_code/g' "$common_dir/fs/f2fs/compress.c"
    sed -i 's/ZSTD_endStream/zstd_end_stream/g' "$common_dir/fs/f2fs/compress.c"
    sed -i 's/ZSTD_DStreamWorkspaceBound/zstd_dstream_workspace_bound/g' "$common_dir/fs/f2fs/compress.c"
    sed -i 's/ZSTD_DStream/zstd_dstream/g' "$common_dir/fs/f2fs/compress.c"
    sed -i 's/ZSTD_initDStream/zstd_init_dstream/g' "$common_dir/fs/f2fs/compress.c"
    sed -i 's/ZSTD_decompressStream/zstd_decompress_stream/g' "$common_dir/fs/f2fs/compress.c"
    sed -i 's/zstd_cstream_workspace_bound(params.cParams)/zstd_cstream_workspace_bound(\&params.cParams)/g' "$common_dir/fs/f2fs/compress.c"
    sed -i 's/zstd_init_cstream(params,/zstd_init_cstream(\&params,/g' "$common_dir/fs/f2fs/compress.c"
}