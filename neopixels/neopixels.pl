#!/usr/bin/perl

# Example using I2C to control Arduino

use strict;
use warnings;

package Arduino::Neopixel::Stick;

use HiPi 0.67;
use HiPi::Device::I2C;
use parent qw( HiPi::Class );
use Try::Tiny;

__PACKAGE__->create_accessors( qw( device address ) );

use constant {
    
    I2C_DEFAULT_ADDRESS  => 0x55, 

    ## Registers
    REG_CONFIG       => 0x00,
    REG_BRIGHTNESS   => 0x01,
    
    REG_PIXEL_0      => 0x04,
    REG_PIXEL_1      => 0x08,
    REG_PIXEL_2      => 0x0C,
    REG_PIXEL_3      => 0x10,
    REG_PIXEL_4      => 0x14,
    REG_PIXEL_5      => 0x18,
    REG_PIXEL_6      => 0x1C,
    REG_PIXEL_7      => 0x20,

    MAX_REGISTER     => 0x23,

    ## config register bits
    CONFIG_SHOW      => 0x02,
    CONFIG_CLEAR     => 0x04,
};

sub new {
    my($class, %params) = @_;
    $params{address} //= I2C_DEFAULT_ADDRESS;
    $params{device} = HiPi::Device::I2C->new( busmode => 'i2c');
    my $self = $class->SUPER::new( %params );
    if( $self->device->check_address( $self->address ) ) {
        $self->device->select_address( $self->address );
    } else {
        die sprintf('No I2C device found at address 0x%x', $self->address);
    }
    return $self;
}

sub clear {
    my $self = shift;
    # Clear the pixel registers and display
    $self->write_i2c( REG_CONFIG, CONFIG_CLEAR );
}

sub show {
    my( $self ) = @_;
    $self->write_i2c( REG_CONFIG, CONFIG_SHOW );
}

sub set_pixel {
    my( $self, $pixel, $red, $green, $blue, $white) = @_;
    # $pixel can be between 0 & 7;
    $pixel //= 0;
    $pixel &= 7;
    # rgbw values between 0 and 255
    for ( $red, $green, $blue, $white ) {
        $_ //= 0;
        $_ &= 0xff;
    }
    # the pixel register is REG_PIXEL_0 + ( $pixel * 4 )
    my $register = REG_PIXEL_0 + ( $pixel * 4);
    $self->write_i2c( $register, $red, $green, $blue, $white );
}

sub get_pixel {
    my( $self, $pixel) = @_;
    my $register = REG_PIXEL_0 + ( $pixel * 4);
    my @rgbw = $self->read_i2c( $register, 4 );
    return @rgbw;
}

sub set_brightness {
    my( $self, $brightness ) = @_;
    $brightness //=0;
    $brightness &= 0xff;
    $self->write_i2c( REG_BRIGHTNESS, $brightness );
    $self->show();
}

sub get_brightness {
    my( $self ) = @_;
    my @vals = $self->read_i2c( REG_BRIGHTNESS, 1 );
    return $vals[0];
}

sub wait {
    my( $self, $millis) = @_;
    $self->device->delay( $millis );
}

sub write_i2c {
    my ( $self, @bytes ) = @_;
    # Arduino may fail to respond before the I2C clock expects.
    # We'll ignore it here
    my $result = try {
        $self->device->bus_write( @bytes );
        return 1;
    } catch {
        warn $_;
        return 0;
    };
    return $result;
}

sub read_i2c {
    my ( $self, $register, $numbytes ) = @_;
    # Arduino may fail to respond before the I2C clock expects.
    # We'll ignore it here
    my @values = try {
        return $self->device->bus_read( $register, $numbytes );
    } catch {
        warn sprintf(qq(failed to read $numbytes bytes from register 0x%x), $register);
        return ();
    };
    
    return @values;
}

###############################################################

package main;

my $max_brightness = 100;

my @red = ( 255, 0, 0 );
my @green = ( 0, 255, 0 );
my @blue = ( 0, 0, 255 );
my @yellow = ( 255, 255, 0 );
my @cyan = ( 0, 255, 255 );
my @magenta = ( 255, 0, 255 );
my @orange = ( 255, 140, 0 );
my @white = ( 255, 255, 255 );
my @brightwhite = ( 255, 255, 255, 255 );

my @pixelbuffer = (
    [ 255, 0, 0, 0 ],
    [ 0, 255, 0, 0 ],
    [ 0, 0, 255, 0 ],
    [ 0, 0, 0, 255 ],
    [ 255, 255, 0, 0 ],
    [ 0, 255, 255, 0 ],
    [ 255, 0, 255, 0 ],
    [ 255, 255, 255, 0 ],
);

my $stick = Arduino::Neopixel::Stick->new( address => 0x55 );

$stick->clear;

$stick->set_brightness( 5 );

set_all_colour( @brightwhite );
$stick->wait(2500);

do_pixel_buffer();
$stick->wait(2500);

# cycle colours for a bit

my $stop = time + 5;
while ( $stop > time ) {
    do_pixel_buffer();
    unshift( @pixelbuffer, pop( @pixelbuffer) );
    $stick->wait( 150 );    
}

# set colours and fade in / out

for my $colour ( \@white, \@red, \@green, \@blue, \@yellow, \@cyan, \@magenta, \@orange ) {

    set_all_colour( @$colour );
    
    my $brightness = 5;
    while( $brightness < $max_brightness ) {
        $stick->set_brightness( $brightness );
        $stick->wait(50);
        $brightness += 5;
    }
    
    while( $brightness >= 0 ) {
        $stick->set_brightness( $brightness );
        $stick->wait(50);
        $brightness -= 5;
    }
}

$stick->clear;

# check read i2c read functions

$stick->set_brightness( 17 );
my $bval = $stick->get_brightness();

print qq(brightness is $bval\n);

$stick->set_pixel(3, 10,21,32,44);
$stick->show;

my @testpixel = $stick->get_pixel(3);

print qq(pixel test returns ) . join(', ', @testpixel ) . qq(\n);
$stick->wait(2500);
$stick->clear;

# end

sub do_pixel_buffer {
    for( my $i = 0; $i < 8; $i++ ) {
        $stick->set_pixel($i, @{ $pixelbuffer[$i] } );
    }
    $stick->show();
}

sub set_all_colour {
    my @colour = @_;
    for( my $i = 0; $i < 8; $i++ ) {
        $stick->set_pixel($i,@colour );
    }
    $stick->show();
}

1;

__END__