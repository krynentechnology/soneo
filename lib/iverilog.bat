echo off
:: make file for Icarus Verilog simulator
if not "%1"=="" (
  if not defined IVERILOG (
    set IVERILOG=%1
    set PATH=%PATH%;%1\bin;%1\lib
  )
)
if not defined IVERILOG (
  echo Run batch file with path to Icarus Verilog simulator installed directory
  echo as first argument. "VCD" argument is optional afterwards for defining
  echo GTK_WAVE to generate VCD file. Other argument skips vvp execution.
  goto :END
)
if exist .\bin rmdir /Q/S bin
if not exist .\bin mkdir bin
cd .\bin
if [%1]==[] (
  iverilog.exe -o aes_tb.out -I .. ..\aes_dec.v ..\aes_enc.v ..\aes_tb.sv
  iverilog.exe -o apcm_sbc4_tb.out -I .. ..\apcm_sbc4_enc.v ..\apcm_sbc4_dec.v ..\apcm_sbc4_tb.sv
  iverilog.exe -o compander_tb.out -I .. ..\compander.v ..\compander_tb.sv
  iverilog.exe -o equalizer_tb.out -I .. ..\equalizer.v ..\equalizer_tb.sv
  iverilog.exe -o i2c_m_tb.out -I .. -g2009 ..\i2c_m.v ..\i2c_m_tb.sv
  iverilog.exe -o i2s_tdm_tb.out -I .. ..\i2s_tdm_enc.v ..\i2s_tdm_dec.v ..\i2s_tdm_tb.sv
  iverilog.exe -o interpolator_tb.out -I .. ..\interpolator.v ..\interpolator_tb.sv
  iverilog.exe -o limiter_tb.out -I .. ..\limiter.v ..\limiter_tb.sv
  iverilog.exe -o randomizer_tb.out -I .. ..\randomizer.v ..\randomizer_tb.sv
  iverilog.exe -o shift_tb.out -I .. ..\shift_p2s.v ..\shift_s2p.v ..\shift_tb.sv
  iverilog.exe -o sine_wg_cor_tb.out -I .. ..\sine_wg_cor.v ..\sine_wg_cor_tb.sv
  iverilog.exe -o spi_tb.out -I .. ..\spi_master.v ..\spi_slave.v ..\spi_io.v ..\spi_tb.sv
  iverilog.exe -o uart_tb.out -I .. ..\uart.v ..\uart_io.v ..\uart_tb.sv
  iverilog.exe -o vu_meter_tb.out -I .. ..\vu_meter.v ..\vu_meter_tb.sv
) else (
  if "%1"=="VCD" (
    iverilog.exe -DGTK_WAVE -o aes_tb.out -I .. ..\aes_dec.v ..\aes_enc.v ..\aes_tb.sv
    iverilog.exe -DGTK_WAVE -o apcm_sbc4_tb.out -I .. ..\apcm_sbc4_enc.v ..\apcm_sbc4_dec.v ..\apcm_sbc4_tb.sv
    iverilog.exe -DGTK_WAVE -o compander_tb.out -I .. ..\compander.v ..\compander_tb.sv
    iverilog.exe -DGTK_WAVE -o equalizer_tb.out -I .. ..\equalizer.v ..\equalizer_tb.sv
    iverilog.exe -DGTK_WAVE -o i2c_m_tb.out -I .. -g2009 ..\i2c_m.v ..\i2c_m_tb.sv
    iverilog.exe -DGTK_WAVE -o i2s_tdm_tb.out -I .. ..\i2s_tdm_enc.v ..\i2s_tdm_dec.v ..\i2s_tdm_tb.sv
    iverilog.exe -DGTK_WAVE -o interpolator_tb.out -I .. ..\interpolator.v ..\interpolator_tb.sv
    iverilog.exe -DGTK_WAVE -o limiter_tb.out -I .. ..\limiter.v ..\limiter_tb.sv
    iverilog.exe -DGTK_WAVE -o randomizer_tb.out -I .. ..\randomizer.v ..\randomizer_tb.sv
    iverilog.exe -DGTK_WAVE -o shift_tb.out -I .. ..\shift_p2s.v ..\shift_s2p.v ..\shift_tb.sv
    iverilog.exe -DGTK_WAVE -o sine_wg_cor_tb.out -I .. ..\sine_wg_cor.v ..\sine_wg_cor_tb.sv
    iverilog.exe -DGTK_WAVE -o spi_tb.out -I .. ..\spi_master.v ..\spi_slave.v ..\spi_io.v ..\spi_tb.sv
    iverilog.exe -DGTK_WAVE -o uart_tb.out -I .. ..\uart.v ..\uart_io.v ..\uart_tb.sv
    iverilog.exe -DGTK_WAVE -o vu_meter_tb.out -I .. ..\vu_meter.v ..\vu_meter_tb.sv
  ) else (
    iverilog.exe -I .. ..\aes_dec.v ..\aes_enc.v ..\aes_tb.sv
    iverilog.exe -I .. ..\apcm_sbc4_enc.v ..\apcm_sbc4_dec.v ..\apcm_sbc4_tb.sv
    iverilog.exe -I .. ..\compander.v ..\compander_tb.sv
    iverilog.exe -I .. ..\equalizer.v ..\equalizer_tb.sv
    iverilog.exe -I .. -g2009 ..\i2c_m.v ..\i2c_m_tb.sv
    iverilog.exe -I .. ..\i2s_tdm_enc.v ..\i2s_tdm_dec.v ..\i2s_tdm_tb.sv
    iverilog.exe -I .. ..\interpolator.v ..\interpolator_tb.sv
    iverilog.exe -I .. ..\limiter.v ..\limiter_tb.sv
    iverilog.exe -I .. ..\randomizer.v ..\randomizer_tb.sv
    iverilog.exe -I .. ..\shift_p2s.v ..\shift_s2p.v ..\shift_tb.sv
    iverilog.exe -I .. ..\sine_wg_cor.v ..\sine_wg_cor_tb.sv
    iverilog.exe -I .. ..\spi_master.v ..\spi_slave.v ..\spi_io.v ..\spi_tb.sv
    iverilog.exe -I .. ..\uart.v ..\uart_io.v ..\uart_tb.sv
    iverilog.exe -I .. ..\vu_meter.v ..\vu_meter_tb.sv
  )
)
if exist aes_tb.out vvp.exe aes_tb.out
if exist apcm_sbc4_tb.out vvp.exe apcm_sbc4_tb.out
if exist compander_tb.out vvp.exe compander_tb.out
if exist equalizer_tb.out vvp.exe equalizer_tb.out
if exist i2c_m_tb.out vvp.exe i2c_m_tb.out
if exist i2s_tdm_tb.out vvp.exe i2s_tdm_tb.out
if exist interpolator_tb.out vvp.exe interpolator_tb.out
if exist limiter_tb.out vvp.exe limiter_tb.out
if exist randomizer_tb.out vvp.exe randomizer_tb.out
if exist shift_tb.out vvp.exe shift_tb.out
if exist sine_wg_cor_tb.out vvp.exe sine_wg_cor_tb.out
if exist spi_tb.out vvp.exe spi_tb.out
if exist uart_tb.out vvp.exe uart_tb.out
if exist vu_meter_tb.out vvp.exe vu_meter_tb.out
cd ..
:END
