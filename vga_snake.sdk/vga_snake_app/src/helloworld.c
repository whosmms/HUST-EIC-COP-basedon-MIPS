/******************************************************************************
*
* VGA Snake SDK monitor application.
*
* The snake game logic and VGA renderer are implemented in RTL. MicroBlaze reads
* the board buttons and game status through AXI GPIO, then reports them over
* UART so the hardware/software system can be verified from SDK.
*
******************************************************************************/

#include "platform.h"
#include "sleep.h"
#include "xgpio.h"
#include "xil_printf.h"
#include "xparameters.h"
#include "xstatus.h"

#define GPIO_DEVICE_ID      XPAR_AXI_GPIO_0_DEVICE_ID

#define GPIO_CH_BUTTONS     1U
#define GPIO_CH_STATUS      2U

#define BTN_CENTER_MASK     0x01U
#define BTN_UP_MASK         0x02U
#define BTN_LEFT_MASK       0x04U
#define BTN_RIGHT_MASK      0x08U
#define BTN_DOWN_MASK       0x10U
#define BTN_MASK            0x1FU

#define STATUS_SCORE_MASK   0x0000FFFFU
#define STATUS_STATE_SHIFT  16U
#define STATUS_STATE_MASK   0x00030000U
#define STATUS_LIVES_SHIFT  18U
#define STATUS_LIVES_MASK   0x003C0000U

#define GAME_STATE_IDLE     0U
#define GAME_STATE_RUNNING  1U
#define GAME_STATE_PAUSE    2U
#define GAME_STATE_GAMEOVER 3U

static XGpio Gpio;

static const char *state_name(unsigned int state)
{
    switch (state) {
    case GAME_STATE_IDLE:
        return "IDLE";
    case GAME_STATE_RUNNING:
        return "RUNNING";
    case GAME_STATE_PAUSE:
        return "PAUSE";
    case GAME_STATE_GAMEOVER:
        return "GAMEOVER";
    default:
        return "UNKNOWN";
    }
}

static unsigned int status_state(unsigned int status)
{
    return (status & STATUS_STATE_MASK) >> STATUS_STATE_SHIFT;
}

static int is_quiet_state(unsigned int state)
{
    return (state == GAME_STATE_IDLE) ||
           (state == GAME_STATE_PAUSE) ||
           (state == GAME_STATE_GAMEOVER);
}

static void print_buttons(unsigned int buttons)
{
    xil_printf("buttons:");

    if (buttons & BTN_UP_MASK) {
        xil_printf(" UP");
    }
    if (buttons & BTN_DOWN_MASK) {
        xil_printf(" DOWN");
    }
    if (buttons & BTN_LEFT_MASK) {
        xil_printf(" LEFT");
    }
    if (buttons & BTN_RIGHT_MASK) {
        xil_printf(" RIGHT");
    }
    if (buttons & BTN_CENTER_MASK) {
        xil_printf(" CENTER");
    }
    if ((buttons & BTN_MASK) == 0U) {
        xil_printf(" none");
    }
}

static void print_status(unsigned int buttons, unsigned int status)
{
    unsigned int score = status & STATUS_SCORE_MASK;
    unsigned int state = (status & STATUS_STATE_MASK) >> STATUS_STATE_SHIFT;
    unsigned int lives = (status & STATUS_LIVES_MASK) >> STATUS_LIVES_SHIFT;

    xil_printf("state=%s score=%u lives=%u ",
               state_name(state), score, lives);
    print_buttons(buttons);
    xil_printf("\r\n");
}

int main(void)
{
    int status;
    unsigned int buttons;
    unsigned int game_status;
    unsigned int sampled_buttons = 0U;
    unsigned int last_buttons = 0xFFFFFFFFU;
    unsigned int last_status = 0xFFFFFFFFU;
    unsigned int last_quiet_state = 0xFFFFFFFFU;
    int quiet_state_printed = 0;

    init_platform();



    status = XGpio_Initialize(&Gpio, GPIO_DEVICE_ID);
    if (status != XST_SUCCESS) {
        xil_printf("ERROR: XGpio_Initialize failed, status=%d\r\n", status);
        cleanup_platform();
        return XST_FAILURE;
    }

    XGpio_SetDataDirection(&Gpio, GPIO_CH_BUTTONS, BTN_MASK);
    XGpio_SetDataDirection(&Gpio, GPIO_CH_STATUS, STATUS_SCORE_MASK | STATUS_STATE_MASK | STATUS_LIVES_MASK);

    xil_printf("AXI GPIO ready. Monitoring buttons and game status...\r\n\r\n");

    while (1) {
        unsigned int state;
        unsigned int button_press;
        int should_print;

        buttons = XGpio_DiscreteRead(&Gpio, GPIO_CH_BUTTONS) & BTN_MASK;
        game_status = XGpio_DiscreteRead(&Gpio, GPIO_CH_STATUS);
        state = status_state(game_status);
        button_press = buttons & ~sampled_buttons;

        should_print = (buttons != last_buttons) || (game_status != last_status);

        if (is_quiet_state(state)) {
            if (state != last_quiet_state) {
                quiet_state_printed = 0;
            }
            should_print = (!quiet_state_printed) || (button_press != 0U);
        } else {
            last_quiet_state = 0xFFFFFFFFU;
            quiet_state_printed = 0;
        }

        if (should_print) {
            print_status(buttons, game_status);
            if (is_quiet_state(state)) {
                last_quiet_state = state;
                quiet_state_printed = 1;
            }
            last_buttons = buttons;
            last_status = game_status;
        }

        sampled_buttons = buttons;
        usleep(100000);
    }

    cleanup_platform();
    return XST_SUCCESS;
}
