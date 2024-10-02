echo off
:: make file for Icarus Verilog simulator
if not defined IVERILOG (
  set IVERILOG=%1
  set ADD_IVERILOG_PATH=Y
)
if not defined IVERILOG (
  echo run batch file with path to Icarus Verilog simulator installed directory
  echo as first argument, same argument is optional afterwards for defining
  echo GTK_WAVE
  goto :END
)
if %ADD_IVERILOG_PATH%==Y set PATH=%PATH%;%IVERILOG%\bin
set ADD_IVERILOG_PATH=N
if exist .\bin rmdir /Q/S bin
if not exist .\bin mkdir bin
cd .\bin
if "%1"=="" (
  iverilog -o aes_tb.out -I .. ..\aes_dec.v ..\aes_enc.v ..\aes_tb.sv
  iverilog -o apcm_sbc4_tb.out -I .. ..\apcm_sbc4_enc.v ..\apcm_sbc4_dec.v ..\apcm_sbc4_tb.sv
  iverilog -o compander_tb.out -I .. ..\compander.v ..\compander_tb.sv
  iverilog -o equalizer_tb.out -I .. ..\equalizer.v ..\equalizer_tb.sv
  iverilog -o i2s_tdm_tb.out -I .. ..\i2s_tdm_enc.v ..\i2s_tdm_dec.v ..\i2s_tdm_tb.sv
  iverilog -o interpolator_tb.out -I .. ..\interpolator.v ..\interpolator_tb.sv
  iverilog -o randomizer_tb.out -I .. ..\randomizer.v ..\randomizer_tb.sv
  iverilog -o sine_wg_cor_tb.out -I .. ..\sine_wg_cor.v ..\sine_wg_cor_tb.sv
  iverilog -o spi_tb.out -I .. ..\spi_master.v ..\spi_slave.v ..\spi_io.v ..\spi_tb.sv
)  
if not "%1"=="" (
  iverilog -DGTK_WAVE -o aes_tb.out -I .. ..\aes_dec.v ..\aes_enc.v ..\aes_tb.sv
  iverilog -DGTK_WAVE -o apcm_sbc4_tb.out -I .. ..\apcm_sbc4_enc.v ..\apcm_sbc4_dec.v ..\apcm_sbc4_tb.sv
  iverilog -DGTK_WAVE -o compander_tb.out -I .. ..\compander.v ..\compander_tb.sv
  iverilog -DGTK_WAVE -o equalizer_tb.out -I .. ..\equalizer.v ..\equalizer_tb.sv
  iverilog -DGTK_WAVE -o i2s_tdm_tb.out -I .. ..\i2s_tdm_enc.v ..\i2s_tdm_dec.v ..\i2s_tdm_tb.sv
  iverilog -DGTK_WAVE -o interpolator_tb.out -I .. ..\interpolator.v ..\interpolator_tb.sv
  iverilog -DGTK_WAVE -o randomizer_tb.out -I .. ..\randomizer.v ..\randomizer_tb.sv
  iverilog -DGTK_WAVE -o sine_wg_cor_tb.out -I .. ..\sine_wg_cor.v ..\sine_wg_cor_tb.sv
  iverilog -DGTK_WAVE -o spi_tb.out -I .. ..\spi_master.v ..\spi_slave.v ..\spi_io.v ..\spi_tb.sv
)  
if exist aes_tb.out vvp aes_tb.out
if exist apcm_sbc4_tb.out vvp apcm_sbc4_tb.out
if exist compander_tb.out vvp compander_tb.out
if exist equalizer_tb.out vvp equalizer_tb.out
if exist i2s_tdm_tb.out vvp i2s_tdm_tb.out
if exist interpolator_tb.out vvp interpolator_tb.out
if exist randomizer_tb.out vvp randomizer_tb.out
if exist sine_wg_cor_tb.out vvp sine_wg_cor_tb.out
if exist spi_tb.out vvp spi_tb.out
cd ..
:END
