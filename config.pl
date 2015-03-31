+{
    output    => 1,
    post_url  => 'http://localhost:5000/weight',
    wipi_name => 'sample',
    device    => +{
        port      => '/dev/tty.usbserial-FTB3L61X',
        baudrate  => 9600,
        parity    => 'even',    # even / odd / none
        databits  => 7,
        stopbits  => 1,
        handshake => 'none',    # none / rts / xoff
    },
    protocol  => +{
        is_stream     => 1,
        command       => '',
        delimiter     => "\n",
        data_len      => 18,
        status_ch_pos => 0,
        stable_ch     => 'S',
        weight_start  => 6,
        weight_len    => 8,
    },
};
