set_defconfig() {
    abk_log "配置内核选项……"

#    abk_enable_config CONFIG_BOEFFLA_WL_BLOCKER
    abk_enable_config CONFIG_DEFAULT_FQ_CODEL
    abk_enable_config CONFIG_LRU_GEN_ENABLED
    abk_enable_config CONFIG_NET_SCH_DEFAULT
    abk_enable_config CONFIG_WQ_POWER_EFFICIENT_DEFAULT

    abk_disable_config CONFIG_ARM64_PTR_AUTH
    abk_disable_config CONFIG_IKHEADERS
    abk_disable_config CONFIG_RCU_LAZY_DEFAULT_OFF
    abk_disable_config CONFIG_UBSAN
    abk_disable_config CONFIG_UBSAN_TRAP
    abk_disable_config CONFIG_UBSAN_LOCAL_BOUNDS

    abk_set_config "CONFIG_CMDLINE" '"stack_depot_disable=on kasan=off kvm-arm.mode=protected cgroup_disable=pressure noirqdebug"'
}