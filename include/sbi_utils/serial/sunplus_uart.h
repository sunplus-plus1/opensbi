#ifndef __SERIAL_SUNPLUS_UART_H__
#define __SERIAL_SUNPLUS_UART_H__

#include <sbi/sbi_types.h>

struct uart_regs {
        unsigned int dr;  /* data register */
        unsigned int lsr; /* line status register */
        unsigned int msr; /* modem status register */
        unsigned int lcr; /* line control register */
        unsigned int mcr; /* modem control register */
        unsigned int div_l;
        unsigned int div_h;
        unsigned int isc; /* interrupt status/control */
        unsigned int txr; /* tx residue */
        unsigned int rxr; /* rx residue */
        unsigned int thr; /* rx threshold */
};

void sunplus_uart_putc(char ch);

int sunplus_uart_getc(void);

int sunplus_uart_init(unsigned long base, u32 baudrate);

#endif