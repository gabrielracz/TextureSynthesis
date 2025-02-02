int noiseSeed = 1337;
float noiseScale = 0.01;
float noiseXBias = 1.0;
int numOctaves = 5;
float threshold = 0.4;
float octaveBase = 2;
boolean shouldThreshold = false;
int peakOctaveLimit = 3;

int IX(int x, int y) { return y * width + x; }

OpenSimplex2S noiseGen;

void setup()
{
  size(800, 800);
  noiseGen = new OpenSimplex2S();
  //noLoop();
}

void draw()
{
  loadPixels();
  
  for(int y = 0; y < height; y++) {
    for(int x = 0; x < width; x++) {
      float accum = 0.0;
      for(int o = 0; o < numOctaves; o++) {
        //float n = OpenSimplex2S.noise2(noiseSeed, x * noiseScale, y * noiseScale);
        float xscale = (o > peakOctaveLimit) ? noiseXBias : 1;
        float n = OpenSimplex2S.noise2(noiseSeed,
                                       x * pow(2, o) * noiseScale * xscale,
                                       y * pow(2, o) * noiseScale);
                                       
        float intensity;
        if( o <= peakOctaveLimit) intensity = map(n, -1.0, 1.0, 0.0, 255.0);
        else intensity = abs(n) * 255.0;
        accum += pow(octaveBase, -(o + 1)) * intensity;
      }
      float finalIntensity = accum;
      if(shouldThreshold) {
        finalIntensity = (accum < (threshold * 255.0)) ? 255.0 : 0.0;
      }
      pixels[IX(x, y)] = color(finalIntensity);
    }
  }
  updatePixels();
}

void mouseWheel(MouseEvent event) {
  float scrollSens = 0.001;
  float scroll = event.getCount();
  noiseScale += scrollSens * scroll;
}

void keyPressed() {
  if (keyCode == 'Q') numOctaves = max(1, numOctaves - 1);
  if (keyCode == 'W') numOctaves += 1;
  if (keyCode == 'E') threshold -= 0.025;
  if (keyCode == 'R') threshold += 0.025;
  if (keyCode == 'T') noiseXBias -= 0.05;
  if (keyCode == 'Y') noiseXBias += 0.05;
  if (keyCode == 'A') octaveBase -= 0.05;
  if (keyCode == 'S') octaveBase += 0.05;
  if (keyCode == 'D') peakOctaveLimit -= 1;
  if (keyCode == 'F') peakOctaveLimit += 1;
  if (keyCode == '1') shouldThreshold = !shouldThreshold;
  if (keyCode == '0') noiseSeed = int(random(100000000));
}
