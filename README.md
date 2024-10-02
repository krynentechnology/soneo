# SONEO
<p>SONEO is an SR2CB application for digital audio distribution, e.g. public address, congress, intercom or stage performances. NEO is pronounced like the main character name <i>Neo</i> from the SciFi movie <i>the Matrix</i>. A data transmission rate of 20k SR2CB frames per second gives a byte channel speed of 160kb/s (20k times 8 bits) and offers 608 byte channels for 100BASE-TX and 6233 byte channels for 1000BASE-T PHYs. The 160kb/s is high enough for good audio quality APCM (32kHz voice - low latency - described in the Bluetooth A2DP specification) and Opus (48kHz voice and music) codecs - if required AES encrypted and authenticated. Multiple byte channels can be combined to distribute 48kHz companding or uncompressed audio.</p>
<p>The SONEO library provides general modules for (multi channel) audio DSP:</p>
<ul>
  <li><a href="lib/aes_enc.v">AES-128</a>  (supports "DEFAULT", "FAST" and "TINY" configuration)</li>
  <li><a href="lib/apcm_sbc4_enc.v">APCM</a>  (Bluetooth A2DP 16-bits audio codec)</li>
  <li><a href="lib/compander.v">Compander</a>  (20/27-bit compander to/from 16-bit two's complement)</li>
  <li><a href="lib/equalizer.v">Equalizer</a>  (IIR filter biquad cascaded bands)</li>
  <li><a href="lib/i2s_tdm_enc.v">I2S/TDM</a>  (I2S/TDM encoder and decoder)</li>
  <li><a href="lib/interpolator.v">Interpolator</a>  (1st, 2nd, 3rd, 4th and 5th order polynomial)</li>
  <li><a href="lib/randomizer.v">Randomizer</a>  (Periodic noise generator, Galois LFSR based)</li>
  <li><a href="lib/sine_wg_cor.v">Sine Wave Generator</a>  (CORDIC algorithm based)</li>
  <li><a href="lib/spi_slave.v">SPI</a>  (master/slave and io - read/write, interrupt)</li>
</ul>
