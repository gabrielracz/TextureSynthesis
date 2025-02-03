import java.util.Arrays;

int noiseSeed = 1337;
float noiseScale = 0.005;
float noiseXBias = 0.25;
float noiseYBias = 1.00;
int numOctaves = 5;
float threshold = 0.225;
float octaveBase = 2.4;
boolean shouldThreshold = true;
int peakOctaveLimit = 2;

  
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

int IX(int x, int y) { return y * width + x; }

OpenSimplex2S noiseGen;

void setup()
{
  size(800, 800);
  noiseGen = new OpenSimplex2S();
  //noLoop();
}

void generateShardNoise(int[] arr, int nOctaves, float scale, float xBias, float yBias, float threshold, float amplitudeBase, int peakOctaves, long seed) {
  float offset = random(100);
  for(int y = 0; y < height; y++) {
    for(int x = 0; x < width; x++) {
      float accum = 0.0;
      for(int o = 0; o < nOctaves; o++) {
        //float n = OpenSimplex2S.noise2(noiseSeed, x * noiseScale, y * noiseScale);
        float xscale = (o > peakOctaves) ? xBias : 1;
        float n = OpenSimplex2S.noise2(seed,
                                       x * pow(2, o) * scale * xscale + offset,
                                       y * pow(2, o) * scale * yBias + offset);              
        float intensity;
        if( o <= peakOctaves) intensity = map(n, -1.0, 1.0, 0.0, 255.0);
        else intensity = abs(n) * 255.0;
        accum += pow(amplitudeBase, -(o + 1)) * intensity;
      }
      float finalIntensity = accum;
      //if(shouldThreshold) {
      if(threshold > 0.0) {
        finalIntensity = (accum < (threshold * 255.0)) ? 255.0 : 0.0;
      }
      arr[IX(x, y)] = color(finalIntensity);
    }
  }
}

void draw()
{
  
  
  loadPixels();
  // shard pieces
  Arrays.fill(pixels, color(0, 0, 0));
  updatePixels();
  loadPixels();
  
  int[] shards = new int[pixels.length]; 
  int[] shardEdges = new int[pixels.length];
  int[] shardGradients = new int[pixels.length];
  int[] smallCrackTexture = new int[pixels.length];
  int[] largeCrackTexture = new int[pixels.length];
  int[] rotatedShards = new int[pixels.length]; 
  int[] rotatedCracks = new int[pixels.length]; 
  int[] texturedShards = new int[pixels.length];
  int[] baseColor = new int[pixels.length];
  Arrays.fill(baseColor, color(81, 75, 63));
  
  int numLayers = 20;
  for(int layer = 0; layer < numLayers; layer++) {
    Arrays.fill(shardEdges, color(0, 0, 0));
    Arrays.fill(shardGradients, color(0, 0, 0));
    Arrays.fill(smallCrackTexture, color(0, 0, 0));
    Arrays.fill(largeCrackTexture, color(0, 0, 0)); 
    Arrays.fill(rotatedCracks, color(0, 0, 0)); 
    Arrays.fill(texturedShards, color(0, 0, 0));
    
    float rotation = random(-PI/4, PI/4);
    
    // BASE SHARD SHAPES
    int seed = int(random(100000000));
    generateShardNoise(shards, 5, 0.005, 0.25, 1.00, 0.225, 2.4, 1, int(random(100000000)));
    applySobelGradient(shards, shardGradients);
    
    // SHARD TEXTURE
    // large cracks
    generateShardNoise(largeCrackTexture, 5, 0.0085, 0.4, 12.05, 0.375, 2.4, -1, int(random(100000000)));
    invertColors(largeCrackTexture);
  
    // small cracks texture
    generateShardNoise(smallCrackTexture, 5, 0.03, 0.4, 9.05, 0.0, 2.4, -1, int(random(100000000)));
    invertColors(smallCrackTexture);
    
    // combine cracks into ont texture
    addBlend(largeCrackTexture, smallCrackTexture, 0.5);

    // apply texture to inside of shards
    maskLayer(shards, baseColor, texturedShards, 1.0);
    maskLayer(shards, largeCrackTexture, texturedShards, 0.3);
    
    // apply jitter edges to shard texture
    jitterEdges(shardGradients, baseColor, shardEdges);
    addBlend(texturedShards, shardEdges, 1.0);
    
    // ROTATE SHARDS
    rotateImage(texturedShards, rotatedShards, rotation);

    float alpha = 1.0 * ((1.0/(numLayers*1.5)) * (layer + 1));
    addBlend(pixels, rotatedShards, alpha);
    println("Layer:", layer+1);
    
    //arrayCopy(shardEdges, pixels);
  }
  updatePixels();
  println("DONE\n");
}

/* UTILS */

void jitterEdges(int[] input, int[] layer, int[] output) {
  int seed = int(random(100000));
  float noiseX = random(100);
  for(int y = 10; y < height-1; y++) {
    for(int x = 10; x < width-1; x++) {
      color sample = input[IX(x, y)];
      //if(input[IX(x, y)] != color(0, 0, 0)) {
      //println(red(sample));
      
      int start;
      int end;
      if(red(sample) != 127) {

        //int r = int(random(15) + 1);
        float maxJitter = 15.0;
        int r = int(abs(OpenSimplex2S.noise2(seed, noiseX, y*0.1)) * maxJitter);
        // jitter inwards towards the shard contents
        if(red(sample) < 127) {
          start = -r;
          end = 0;
        } else {
          start = 1;
          end = r + 1;
        }
        
        for(int j = start; j < end; j++) {
          int shiftedix = IX(constrain(x + j, 0, width - 1), y);
          output[shiftedix] = layer[shiftedix];
          //output[shiftedix] = color(255);
        }
      }
    }
  }
}

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

void applySobelGradient(int[] input, int[] result) {
  int w = width, h = height;

  float[][] sobelX = {
    {-1, 0, 1},
    {-2, 0, 2},
    {-1, 0, 1}
  };

  float[][] sobelY = {
    {-1, -2, -1},
    { 0,  0,  0},
    { 1,  2,  1}
  };

  for (int y = 1; y < h - 1; y++) {
    for (int x = 1; x < w - 1; x++) {
      float gx = 0, gy = 0;

      for (int ky = -1; ky <= 1; ky++) {
        for (int kx = -1; kx <= 1; kx++) {
          int px = (x + kx) + (y + ky) * w;
          float intensity = brightness(input[px]); // Since image is B&W, we can use brightness

          gx += intensity * sobelX[ky + 1][kx + 1];
          gy += intensity * sobelY[ky + 1][kx + 1];
        }
      }

      // Map gradients to 0-255 range
      int r = int(map(gx, -255, 255, 0, 255)); // Store Gx in red channel
      int b = int(map(gy, -255, 255, 0, 255)); // Store Gy in green channel
      result[x + y * w] = color(r, 0, b); // Red = Gx, Green = Gy, Blue = 0
    }
  }
}

void maskLayer(int[] mask, int[] layer, int[] output, float alpha) {
  for(int y = 0; y < height; y++) {
    for(int x = 0; x < width; x++) {
      int i = IX(x, y);
      if(mask[i] != color(0, 0, 0)) {
        output[i] = addColors(output[i], layer[i], 1.0, alpha);
      }
    }
  }
}

void addBlend(int[] a, int[] b, float alpha) {
  for(int i = 0; i < a.length; i++) {
    a[i] = addColors(a[i], b[i], 1.0, alpha);
  }
}

void addBlendAlpha(int[] a, int[] b, float a1, float a2) {
  for(int i = 0; i < a.length; i++) {
    a[i] = addColors(a[i], b[i], a1, a2);
  }
}

color addColors(color c1, color c2, float a1, float a2) {
  int r = int(constrain(red(c1) * a1 + red(c2) * a2, 0, 255));
  int g = int(constrain(green(c1) * a1 + green(c2) * a2, 0, 255));
  int b = int(constrain(blue(c1) * a1 + blue(c2) * a2, 0, 255));
  
  return color(r, g, b);
}

void invertColors(int[] pixelArray) {
  for (int i = 0; i < pixelArray.length; i++) {
    pixelArray[i] = color(255 - red(pixelArray[i]), 255 - green(pixelArray[i]), 255 - blue(pixelArray[i]));
  }
}

void rotateImage(int[] input, int[] output, float angle) {
  float cx = (width - 1) / 2.0;  // Center X
  float cy = (height - 1) / 2.0;  // Center Y
  
  float cosA = cos(angle);
  float sinA = sin(angle);

  for (int y = 0; y < width; y++) {
    for (int x = 0; x < height; x++) {
      // Map (x, y) to centered coordinates
      float nx = x - cx;
      float ny = y - cy;

      // Apply inverse rotation
      int srcX = round(cx + (nx * cosA - ny * sinA));
      int srcY = round(cy + (nx * sinA + ny * cosA));

      // Bounds check
      if (srcX >= 0 && srcX < width && srcY >= 0 && srcY < height) {
        output[IX(x, y)] = input[IX(srcX, srcY)];
      } else {
        output[IX(x, y)] = color(0); // Fill with black if out of bounds
      }
    }
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
