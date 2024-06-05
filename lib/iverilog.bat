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
  iverilog -o interpolator_tb.out -I .. ..\interpolator.v ..\interpolator_tb.sv
  iverilog -o equalizer_tb.out -I .. ..\equalizer.v ..\equalizer_tb.sv
)  
if not "%1"=="" (
  iverilog -DGTK_WAVE -o interpolator_tb.out -I .. ..\interpolator.v ..\interpolator_tb.sv
  iverilog -DGTK_WAVE -o equalizer_tb.out -I .. ..\equalizer.v ..\equalizer_tb.sv
)  
if exist interpolator_tb.out vvp interpolator_tb.out
if exist equalizer_tb.out vvp equalizer_tb.out
cd ..
:END
