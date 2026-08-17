#!/usr/bin/env bash

builtin_zram() {
    local common_dir
    common_dir="$(abk_common_dir)"

    abk_require_file "$common_dir/android/gki_aarch64_modules"
    abk_require_file "$common_dir/drivers/block/zram/zram_drv.c"
    abk_require_file "$common_dir/android/gki_system_dlkm_modules"

    abk_log "内置 ZRAM ……"

    sed -i 's/REQ_OP_READ/REQ_OP_READ | REQ_PRIO/g' "$common_dir/drivers/block/zram/zram_drv.c"
    sed -i 's/parent->bi_opf/parent->bi_opf | REQ_PRIO/g' "$common_dir/drivers/block/zram/zram_drv.c"

    perl -0777 -pi -e 's/mm\/zsmalloc.ko\ndrivers\/block\/zram\/zram.ko//gs' "$common_dir/android/gki_aarch64_modules"
    perl -0777 -pi -e 's/drivers\/block\/zram\/zram.ko\nmm\/zsmalloc.ko//gs' "$common_dir/android/gki_system_dlkm_modules"

    abk_enable_config CONFIG_ZRAM
    abk_enable_config CONFIG_ZSMALLOC
    abk_enable_config CONFIG_ZRAM_WRITEBACK
}

update_zstd() {
    local common_dir
    common_dir="$(abk_common_dir)"

    abk_log "移除旧版本 ZSTD 文件……"
    rm -rf "$common_dir/lib/zstd/.*"
    rm "$common_dir/crypto/zstd.c" "$common_dir/fs/btrfs/zstd.c" "$common_dir/fs/squashfs/zstd_wrapper.c"
    find "$common_dir/include/linux" -name "zstd*.h" | xargs -I {} rm {}

    abk_log "复制新版本 ZSTD 文件……"
    abk_copy_into_kernel "$MODULE_DIR/files/zstd/." "common"

    patch_zstd_lib_kconfig
    patch_zstd_fun_name
}

patch_zstd_lib_kconfig() {
    local common_dir
    common_dir="$(abk_common_dir)"

    abk_require_file "$common_dir/lib/Kconfig"

    abk_log "修补 lib/Kconfig"
    perl -0777 -pi -e 's/config\s+ZSTD_COMPRESS\s+select\s+XXHASH\s+tristate\s+config\s+ZSTD_DECOMPRESS\s+select\s+XXHASH\s+tristate/config ZSTD_COMMON\n\tselect XXHASH\n\ttristate\n\nconfig ZSTD_COMPRESS\n\tselect ZSTD_COMMON\n\ttristate\n\nconfig ZSTD_DECOMPRESS\n\tselect ZSTD_COMMON\n\ttristate/gs' "$common_dir/lib/Kconfig"
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

add_zstdh() {
    local common_dir
    common_dir="$(abk_common_dir)"

    abk_require_file "$common_dir/lib/Kconfig"
    abk_require_file "$common_dir/lib/Makefile"
    abk_require_file "$common_dir/crypto/Kconfig"
    abk_require_file "$common_dir/crypto/Makefile"
    abk_require_file "$common_dir/drivers/block/zram/zcomp.c"

    abk_log "添加 ZSTDH 文件……"
    abk_copy_into_kernel "$MODULE_DIR/files/zstdh/." "common"

    abk_log "修补编译配置文件……"

    perl -0777 -pi -e 's/config\s+ZSTD_DECOMPRESS\n\tselect ZSTD_COMMON\n\ttristate/config ZSTD_DECOMPRESS\n\tselect ZSTD_COMMON\n\ttristate\n\nconfig ZSTDH_COMMON\n\tselect XXHASH\n\ttristate\n\nconfig ZSTDH_COMPRESS\n\tselect ZSTDH_COMMON\n\ttristate\n\nconfig ZSTDH_DECOMPRESS\n\tselect ZSTDH_COMMON\n\ttristate/gs' "$common_dir/lib/Kconfig"
    sed -i 's/obj-$(CONFIG_ZSTD_DECOMPRESS) += zstd\//obj-$(CONFIG_ZSTD_DECOMPRESS) += zstd\/\nobj-$(CONFIG_ZSTDH_COMPRESS) += zstdh\/\nobj-$(CONFIG_ZSTDH_DECOMPRESS) += zstdh\//g' "$common_dir/lib/Makefile"

    perl -0777 -pi -e 's/\s+This is the zstd algorithm./\n\t  This is the zstd algorithm.\n\nconfig CRYPTO_ZSTDH\n\ttristate "Zstdh compression algorithm"\n\tselect CRYPTO_ALGAPI\n\tselect CRYPTO_ACOMP2\n\tselect ZSTDH_COMPRESS\n\tselect ZSTDH_DECOMPRESS\n\thelp\n\t  This is the zstdh algorithm./gs' "$common_dir/crypto/Kconfig"
    sed -i 's/obj-$(CONFIG_CRYPTO_ZSTD) += zstd.o/obj-$(CONFIG_CRYPTO_ZSTD) += zstd.o\nobj-$(CONFIG_CRYPTO_ZSTDH) += zstdh.o/g' "$common_dir/crypto/Makefile"

    perl -0777 -pi -e 's/\s+"zstd",/\n\t"zstd",\n#endif\n#if IS_ENABLED(CONFIG_CRYPTO_ZSTDH)\n\t"zstdh",/gs' "$common_dir/drivers/block/zram/zcomp.c"

    abk_enable_config CONFIG_CRYPTO_ZSTDH
    abk_enable_config CONFIG_ZSTDH_COMMON
    abk_enable_config CONFIG_ZSTDH_COMPRESS
    abk_enable_config CONFIG_ZSTDH_DECOMPRESS
}