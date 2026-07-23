export POLLY_BLOCK=$(cat <<- 'EOF'

ifdef CONFIG_LLVM_POLLY
KBUILD_CFLAGS        += -mllvm -polly \
                   -mllvm -polly-run-inliner \
                   -mllvm -polly-ast-use-context \
                   -mllvm -polly-detect-keep-going \
                   -mllvm -polly-invariant-load-hoisting \
                   -mllvm -polly-vectorizer=stripmine

ifeq ($(shell test $(CONFIG_CLANG_VERSION) -gt 130000; echo $$?),0)
KBUILD_CFLAGS        += -mllvm -polly-loopfusion-greedy=1 \
                   -mllvm -polly-reschedule=1 \
                   -mllvm -polly-postopts=1 \
                   -mllvm -polly-num-threads=0 \
                   -mllvm -polly-omp-backend=LLVM \
                   -mllvm -polly-scheduling=dynamic \
                   -mllvm -polly-scheduling-chunksize=1
else
KBUILD_CFLAGS        += -mllvm -polly-opt-fusion=max
endif

# Polly may optimise loops with dead paths beyound what the linker
# can understand. This may negate the effect of the linker's DCE
# so we tell Polly to perfom proven DCE on the loops it optimises
# in order to preserve the overall effect of the linker's DCE.
ifdef CONFIG_LD_DEAD_CODE_DATA_ELIMINATION
POLLY_FLAGS        += -mllvm -polly-run-dce
endif
endif
EOF)

other_opt() {
    local common_dir
    common_dir="$(abk_common_dir)"

    abk_require_file "$common_dir/Makefile"
    abk_require_file "$common_dir/arch/Kconfig"
    abk_require_file "$common_dir/fs/f2fs/data.c"

    abk_log "其他优化……"
    sed -i 's/find_get_page(mapping, index)/find_get_page_flags(mapping, index, FGP_ACCESSED)/g' "$common_dir/fs/f2fs/data.c"

    abk_copy_into_kernel "$MODULE_DIR/files/arch/llvm/." "common/arch/llvm"

    abk_append_line_once "$common_dir/arch/Kconfig" 'source "arch/llvm/Kconfig"'
    
    target_makefile="$common_dir/Makefile"
    if ! grep -Fq "CONFIG_LLVM_POLLY" "$target_makefile"; then
        awk '{
            print $0;
            if (prev ~ /KBUILD_CFLAGS \+= -Os/ && $0 ~ /^endif/) {
                print ENVIRON["POLLY_BLOCK"]
            }
            prev = $0
        }' "$target_makefile" > "$target_makefile.tmp" && mv "$target_makefile.tmp" "$target_makefile"
    fi
    
    abk_enable_config CONFIG_LLVM_POLLY
}