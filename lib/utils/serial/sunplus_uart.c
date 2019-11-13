#include <sbi/sbi_console.h>
#include <sbi_utils/serial/sunplus_uart.h>

volatile struct uart_regs * sp_uart;
#define UART_REG_STATUS_RX (1 << 1)
#define UART_REG_STATUS_TX (1 << 6) 


void sunplus_uart_putc(char ch)
{
	while ((sp_uart->lsr & UART_REG_STATUS_TX) == 0);
	sp_uart->dr= ch;
}

int sunplus_uart_getc(void)
{
 	if ((sp_uart->lsr & UART_REG_STATUS_RX) == 0);
	return sp_uart->dr;
	
  return -1;
}

int sunplus_uart_init(unsigned long base, u32 baudrate)
{
	sp_uart = (struct uart_regs *)base;
	return 0;

}
