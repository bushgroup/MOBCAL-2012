# MOBCAL-2012
A program for calculating collision cross sections that was reported in https://doi.org/10.1021/ac202625t

## Calculating the Mobilities of Drug-Like Molecular Ions in Helium and Nitrogen
We reported versions of MOBCAL optimized for calculating the mobilities of drug-like molecular ions in helium and in nitrogen gasses [1], based on the original trajectory method [2] and an extension of the method to nitrogen gas [3]. Based on the interest from the community, we have prepared a short getting-started guide.

### Any research that uses this code or the included Lennard-Jones parameters should reference [1].  

### References
1. Campuzano, I. D. G.;* Bush, M. F.;* Robinson, C. V.; Beaumont, C.; Richardson, K.; Kim, H.; Kim, H. I. “Structural Characterization of Drug-like Compounds by Ion Mobility Mass Spectrometry: Comparison of Theoretical and Experimentally Derived Nitrogen Collision Cross-sections.” <i>Anal. Chem.</i> <b>2012</b>, <i>84</i>, 1026-1033.
2. Mesleh, M. F.; Hunter, J. M.; Shvartsburg, A. A.; Schatz, G. C.; Jarrold, M. F. “Structural Information from Ion Mobility Measurements: Effects of the Long Range Potential." <i>J. Phys. Chem.</i> <b>1996</b>, <i>100</i>, 16082-16086.
3. Kim, H; Kim, H. I.; Johnson, P. V.; Beegle, L. W.; Beauchamp J.L.; Goddard, W.A.; Kanik, I. “Experimental and theoretical investigation into the correlation between mass and ion mobility for choline and other ammonium cations in N2.” <i>Anal. Chem.</i> <b>2008</b>, <i>80</i>, 1928-1936.

## Files
+ `mobcal_He.f` Fotran 77 source code
+ `mobcal_N2.f` Fotran 77 source code
+ `mobcal.in` Parameter file. Sets input file name, output file name, and random number seed
+ `Choline.mfj` Input file used for choline in [1]
+ `Choline.He.out` Output file for choline in He gas
+ `Choline.N2.out` Output file for choline in N2 gas

## Environment
All results in [1] were calculated by Iain Campuzano in a Linux environment. Matt Bush has used this code successfully in a Cygwin (http://www.cygwin.com/) environment (with “Devel” options and a text editor) on a Windows PC.

## Compiling source code
Compile using: `g77 -o < file name the compiled code> <fotran code file name>`  
+ Example: `g77 -o mn mobcal_N2.f`  
+ Note that the use of compiler optimization tags, e.g., `-O2`, resulted in binaries that did not execute correctly  
+ Matt did not had success using code compiled using the “gfortran” compiler. Instead, use the legacy “g77” compiler  

## Run the compiled code
+ example: `./mn`  
+ If you use the provided `mobcal.in` file, the resulting `temp.out` file should be <u>exactly</u> the same as the provided output file.  

## Limitations
+ This method has been validated for drug-like small molecular ions in low pressure, ambient temperature He and N2 mobility experiment [1].  
+ This method has not been validated for other ions classes or experiments performed at high pressures or non-ambient temperatures.
