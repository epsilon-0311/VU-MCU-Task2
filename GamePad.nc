// A Thomas Lamprecht <e1327645@student.tuwien.ac> production - 2017

interface GamePad {
    command void request_linear_accel(void);

    async event void linear_accel_ready(int16_t x_acc, int16_t y_acc);
}
