/*
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2019 Western Digital Corporation or its affiliates.
 *
 * Authors:
 *   Atish Patra <atish.patra@wdc.com>
 */

#include <libfdt.h>
#include <fdt.h>
#include <sbi/riscv_encoding.h>
#include <sbi/sbi_const.h>
#include <sbi/sbi_hart.h>
#include <sbi/sbi_console.h>
#include <sbi/sbi_platform.h>
#include <sbi/riscv_io.h>
#include <sbi_utils/irqchip/plic.h>
#include <sbi_utils/serial/sunplus_uart.h>
#include <sbi_utils/sys/clint.h>


/* clang-format off */

#define U54MC_HART_COUNT			5
#define U54MC_HART_STACK_SIZE			8192

#define U54MC_SYS_CLK				1000000000

#define U54MC_CLINT_ADDR			0x2000000

#define U54MC_PLIC_ADDR				0xc000000
#define U54MC_PLIC_NUM_SOURCES			0x35
#define U54MC_PLIC_NUM_PRIORITIES		7

#define U54MC_UART0_ADDR			0x9c000900
#define U54MC_UART_BAUDRATE			115200

/**
 * The U54MC SoC has 5 HARTs but HART ID 0 doesn't have S mode. enable only
 * HARTs 1 to 4.
 */
#ifndef U54MC_ENABLED_HART_MASK
#define U54MC_ENABLED_HART_MASK	(1 << 1 | 1 << 2 | 1 << 3 | 1 << 4)
#endif

#define U54MC_HARITD_DISABLED			~(U54MC_ENABLED_HART_MASK)

/* PRCI clock related macros */
//TODO: Do we need a separate driver for this ?
#define U54MC_PRCI_BASE_ADDR			0x10000000
#define U54MC_PRCI_CLKMUXSTATUSREG		0x002C
#define U54MC_PRCI_CLKMUX_STATUS_TLCLKSEL	(0x1 << 1)

/* clang-format on */


static int U54MC_final_init(bool cold_boot)
{
	void *fdt;

	if (!cold_boot)
		return 0;

	fdt = sbi_scratch_thishart_arg1_ptr();
	plic_fdt_fixup(fdt, "riscv,plic0");
	return 0;
}

static u32 U54MC_pmp_region_count(u32 hartid)
{
	return 1;
}

static int U54MC_pmp_region_info(u32 hartid, u32 index, ulong *prot,
				 ulong *addr, ulong *log2size)
{
	int ret = 0;

	switch (index) {
	case 0:
		*prot	  = PMP_R | PMP_W | PMP_X;
		*addr	  = 0;
		*log2size = __riscv_xlen;
		break;
	default:
		ret = -1;
		break;
	};

	return ret;
}

static int U54MC_console_init(void)
{

	return sunplus_uart_init(U54MC_UART0_ADDR, U54MC_UART_BAUDRATE);
}

static int U54MC_irqchip_init(bool cold_boot)
{
	int rc;
	u32 hartid = sbi_current_hartid();

	if (cold_boot) {
		rc = plic_cold_irqchip_init(U54MC_PLIC_ADDR,
					    U54MC_PLIC_NUM_SOURCES,
					    U54MC_HART_COUNT);
		if (rc)
			return rc;
	}

	return plic_warm_irqchip_init(hartid, (hartid) ? (2 * hartid - 1) : 0,
				      (hartid) ? (2 * hartid) : -1);
}

static int U54MC_ipi_init(bool cold_boot)
{
	int rc;

	if (cold_boot) {
		rc = clint_cold_ipi_init(U54MC_CLINT_ADDR, U54MC_HART_COUNT);
		if (rc)
			return rc;
	}

	return clint_warm_ipi_init();
}

static int U54MC_timer_init(bool cold_boot)
{
	int rc;

	if (cold_boot) {
		rc = clint_cold_timer_init(U54MC_CLINT_ADDR, U54MC_HART_COUNT);
		if (rc)
			return rc;
	}

	return clint_warm_timer_init();
}

static int U54MC_system_down(u32 type)
{
	/* For now nothing to do. */
	return 0;
}

const struct sbi_platform_operations platform_ops = {
	.pmp_region_count	= U54MC_pmp_region_count,
	.pmp_region_info	= U54MC_pmp_region_info,
	.final_init		= U54MC_final_init,
	.console_putc		= sunplus_uart_putc,
	.console_getc		= sunplus_uart_getc,
	.console_init		= U54MC_console_init,
	.irqchip_init		= U54MC_irqchip_init,
	.ipi_send		= clint_ipi_send,
	.ipi_clear		= clint_ipi_clear,
	.ipi_init		= U54MC_ipi_init,
	.timer_value		= clint_timer_value,
	.timer_event_stop	= clint_timer_event_stop,
	.timer_event_start	= clint_timer_event_start,
	.timer_init		= U54MC_timer_init,
	.system_reboot		= U54MC_system_down,
	.system_shutdown	= U54MC_system_down
};

const struct sbi_platform platform = {
	.opensbi_version	= OPENSBI_VERSION,
	.platform_version	= SBI_PLATFORM_VERSION(0x0, 0x01),
	.name			= "SUNPLUS U54-MC",
	.features		= SBI_PLATFORM_DEFAULT_FEATURES,
	.hart_count		= U54MC_HART_COUNT,
	.hart_stack_size	= U54MC_HART_STACK_SIZE,
	.disabled_hart_mask	= U54MC_HARITD_DISABLED,
	.platform_ops_addr	= (unsigned long)&platform_ops
};
