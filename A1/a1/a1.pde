int noiseSeed = 1337;
float noiseScale = 0.005;
float noiseXBias = 0.25;
float noiseYBias = 1.00;
int numOctaves = 5;
float threshold = 0.225;
float octaveBase = 2.4;
boolean shouldThreshold = true;
int peakOctaveLimit = 2;

int IX(int x, int y) { return y * width + x; }

OpenSimplex2S noiseGen;

void setup()
{
  size(800, 800);
  noiseGen = new OpenSimplex2S();
  //noLoop();
}

void generateShardNoise(int nOctaves, float scale, float xBias, float yBias, float threshold, float amplitudeBase, int peakOctaves, long seed) {
  for(int y = 0; y < height; y++) {
    for(int x = 0; x < width; x++) {
      float accum = 0.0;
      for(int o = 0; o < nOctaves; o++) {
        //float n = OpenSimplex2S.noise2(noiseSeed, x * noiseScale, y * noiseScale);
        float xscale = (o > peakOctaves) ? xBias : 1;
        float n = OpenSimplex2S.noise2(noiseSeed,
                                       x * pow(2, o) * scale * xscale,
                                       y * pow(2, o) * scale * yBias);              
        float intensity;
        if( o <= peakOctaves) intensity = map(n, -1.0, 1.0, 0.0, 255.0);
        else intensity = abs(n) * 255.0;
        accum += pow(amplitudeBase, -(o + 1)) * intensity;
      }
      float finalIntensity = accum;
      if(shouldThreshold) {
        finalIntensity = (accum < (threshold * 255.0)) ? 255.0 : 0.0;
      }
      pixels[IX(x, y)] = color(finalIntensity);
    }
  }
}

void draw()
{
  loadPixels();
  // shard pieces
  generateShardNoise(5, 0.005, 0.25, 1.00, 0.225, 2.4, 2, 1337);
  
  // large cracks
  //generateShardNoise(5, 0.003, 0.4, 12.05, 0.375, 2.4, -1, 1337);
  
  
  float[][] edgeKernel = {
    {-1, -1, -1},
    {-1,  8, -1},
    {-1, -1, -1}
  };
  
  float[][] XedgeKernel = {
    {-1, 0, 1},
    {-2, 0, 2},
    {-1, 0, 1}
  };
  // small cracks texture
  int[] result = new int[pixels.length];
  //generateShardNoise(5, 0.03, 0.4, 12.05, 0.375, 2.4, -1, 1337);
  //invertColors(pixels);
  applyConvolution(pixels, edgeKernel, result);
  arrayCopy(result, pixels);
  updatePixels();
}

/* UTILS */

void applyConvolution(int[] pixelArray, float[][] kernel, int[] result) {
  int w = width, h = height;
  //int[] result = new int[pixels.length];

  int kw = kernel.length, kh = kernel[0].length;
  int kCenterX = kw / 2, kCenterY = kh / 2;

  for (int y = kCenterY; y < h - kCenterY; y++) {
    for (int x = kCenterX; x < w - kCenterX; x++) {
      float r = 0, g = 0, b = 0;
      for (int ky = 0; ky < kh; ky++) {
        for (int kx = 0; kx < kw; kx++) {
          int px = (x + kx - kCenterX) + (y + ky - kCenterY) * w;
          color col = pixelArray[px];
          float weight = kernel[ky][kx];
          r += red(col) * weight;
          g += green(col) * weight;
          b += blue(col) * weight;
        }
      }
      int i = x + y * w;
      result[i] = color(constrain(r, 0, 255), constrain(g, 0, 255), constrain(b, 0, 255));
    }
  }

  //arrayCopy(result, pixels);
  //updatePixels();
}

void invertColors(int[] pixelArray) {
  for (int i = 0; i < pixelArray.length; i++) {
    pixelArray[i] = color(255 - red(pixelArray[i]), 255 - green(pixelArray[i]), 255 - blue(pixelArray[i]));
  }
}

/* CONTROLS */
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
  if (keyCode == 'U') noiseYBias -= 0.05;
  if (keyCode == 'I') noiseYBias += 0.05;
  if (keyCode == 'A') octaveBase -= 0.05;
  if (keyCode == 'S') octaveBase += 0.05;
  if (keyCode == 'D') peakOctaveLimit -= 1;
  if (keyCode == 'F') peakOctaveLimit += 1;
  if (keyCode == '1') shouldThreshold = !shouldThreshold;
  if (keyCode == '0') noiseSeed = int(random(100000000));
  //if (keyCode == 'P') {
  // 12.050028 0.3999998   0.0029999996   2.4   -1   0.35000002 5
  println(noiseXBias, noiseYBias, " ", noiseScale, " ", octaveBase, " ", numOctaves, peakOctaveLimit, " ", threshold);
  println(noiseXBias, noiseYBias, " ", noiseScale, " ", octaveBase, " ", numOctaves, peakOctaveLimit, " ", threshold);
}
