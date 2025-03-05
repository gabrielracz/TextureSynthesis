import java.util.Arrays;

PImage exampleImg;
color[] outputArr;
int outWidth, outHeight;

float ErrorThreshold = 30.0;
int MonteCarloSamples = 300;

color[] candidateMatches;
int kernelSize = 23;
float sigma = float(kernelSize) / 6.4; 
float[] gaussianWeights = generateGaussianKernel(kernelSize, sigma);
boolean[] dummyValidMask;

final color INVALID_COLOR = color(0, 0);


int IX(int x, int y) { return y * outWidth + x; }

class Pair {
  int x;
  int y;
  Pair(int x, int y) {
    this.x = x;
    this.y = y;
  }
}

class ScoredColor {
  color col;
  float score;
  
  ScoredColor(color col, float score) {
    this.col = col;
    this.score = score;
  }
}


void initOutputArr(int w, int h) {
  outputArr = new color[w * h];
  outWidth = w;
  outHeight = h;
  Arrays.fill(outputArr, INVALID_COLOR);
}

int winWidth = 256, winHeight = 256;

void settings() {
  size(winWidth, winHeight);
}

void setup() {
  exampleImg = loadImage("cheese.png");
  exampleImg.loadPixels();
  initOutputArr(winWidth, winHeight);
  candidateMatches = new color[exampleImg.pixels.length];
  noLoop();
  randomSeed(1337);
}

float computeSimilarity(int exX, int exY, float[] weights, boolean[] validMask, int outX, int outY) {
  int k = kernelSize / 2;
  //int validCount = 0;
  float accumScore = 0.0;
  float weightSum = 0.0;
  for(int i = 0; i < kernelSize; i++) {
    for(int j = 0; j < kernelSize; j++) {
      int oy = outY + (i - k);
      int ox = outX + (j - k);
      color cmp = outputArr[oy * outWidth + ox];
      if(cmp == INVALID_COLOR) continue;
      
      int y = exY + (i - k);
      int x = exX + (j - k);
      color sample = exampleImg.pixels[y * exampleImg.width + x]; //<>//
      
      float d = colorDistance(sample, cmp);
      float w = weights[i * kernelSize + j];
      //float v = (validMask[i * kernelSize + j]) ? 1.0 : 0.0;
      //float v = (cmp == INVALID_COLOR) ? 0.0 : 1.0;

      float result = d * w;
      //float result = d;
      
      accumScore += result;
      weightSum += w;
    }
  }
  return (weightSum > 0.0) ? (accumScore / weightSum) : 0.0; // Normalize
  //return accumScore; // Normalize
}

color findClosestMatch(int outX, int outY) {
  int k = kernelSize / 2;
  Arrays.fill(candidateMatches, INVALID_COLOR);
  int matches = 0;
  float lowestScore = 10000000.0;
  color closestColor = INVALID_COLOR;
  for(int y = k; y < exampleImg.height - k; y++) {
    for(int x = k; x < exampleImg.width - k; x++) {
      float score = computeSimilarity(x, y, gaussianWeights, dummyValidMask, outX, outY);
      //if(score < ErrorThreshold) {
      //  scoredColors[matches] = new ScoredColor(exampleImg.pixels[y * exampleImg.width + x], score);
      //  matches++;
      //}
      score += random(ErrorThreshold); //randomly jitter score to introduce variance
      if(score < lowestScore) {
        lowestScore = score;
        closestColor = exampleImg.pixels[y * exampleImg.width + x];
      }
    }
  }
  //if(matches == 0) println("NO MATCHES", lowestScore);
  
  //color randPick = candidateMatches[floor(random(matches))];
  //return randPick;
  return closestColor;
}

color findClosestMatchMonte(int outX, int outY, int numTries) {
  int k = kernelSize / 2;
  float lowestScore = 100000000.0;
  color closest = color(1.0, 0.0, 1.0);
  for(int i = 0; i < numTries; i++) {
    int exY = floor(random(k, exampleImg.height - k));
    int exX = floor(random(k, exampleImg.width - k));
    color sample = exampleImg.pixels[exY * exampleImg.width + exX];
    float score = computeSimilarity(exX, exY, gaussianWeights, dummyValidMask, outX, outY);
    if(score < lowestScore) {
      lowestScore = score;
      closest = sample;
    }
  }

  return closest;
}

void initializeTextureSingleCornerPixel(int k) {
  // sample a random pixel from original examplar and place it at the starting point in the output
  int ry = floor(random(exampleImg.height));
  int rx = floor(random(exampleImg.width));
  color randInitialColor = exampleImg.pixels[ry * exampleImg.width + rx];
  outputArr[IX(k, k)] = randInitialColor;
}

void iterateFillTopLeft(int k) {
    for(int y = k + 1; y < outWidth - k; y++) {
    for(int x = k; x < outWidth - k; x++) {
      color match = findClosestMatchMonte(x, y, MonteCarloSamples);
      //color match = findClosestMatch(x, y);
      outputArr[IX(x, y)] = match;
    }
    if(y % 10 == 0) {
        println(y);
    }
  }
}

void initializeTextureTopLeftPatch(int patchSize) {
  int p = patchSize;
  copyRegion(exampleImg.pixels, exampleImg.width, exampleImg.height, 
             floor(random(p, exampleImg.width - p)), floor(random(p, exampleImg.height - p)),
             p, p,
             outputArr, outWidth, outHeight, 0, 0);
}

void initializeTextureCenterPatch(int centerSize) {
  int c = centerSize;
  copyRegion(exampleImg.pixels, exampleImg.width, exampleImg.height, 
             floor(random(c, exampleImg.width - c)), floor(random(c, exampleImg.height - c)),
             centerSize, centerSize,
             outputArr, outWidth, outHeight, outWidth/2 - centerSize/2, outHeight/2 - centerSize/2);
}

void iterateFillGrowCenter(int centerSize) {
  int cx = outWidth / 2;
  int cy = outWidth / 2;
  int x = centerSize/2;
  int y = centerSize/2;
  int k = kernelSize/2;
  
  Pair blankPair = new Pair(0, 0);
  Pair[] pairs = new Pair[outWidth * 2 + outHeight * 2];
  int pairCount = 0;
  
  int xlim = cx - k - 1;
  int ylim = cy - k - 1;
  int cnt = 0;
  while(x < xlim && y < ylim) {
    // generate border cells to center grow
    for(int i = -x; i <= x; i++) {
      pairs[pairCount++] = new Pair(cx + i, cy + y);
      pairs[pairCount++] = new Pair(cx + i, cy - y);
    }
    
    for(int i = -y; i <= y; i++) {
      pairs[pairCount++] = new Pair(cx + x, cy + i);
      pairs[pairCount++] = new Pair(cx - x, cy + i);
    }
    if(x < xlim) x++;
    if(y < ylim) y++;
    
    shufflePairArray(pairs, pairCount);
    for(int j = 0; j < pairCount; j++) {
      Pair p = pairs[j];
      color match = findClosestMatchMonte(p.x, p.y, MonteCarloSamples);
      //color match = findClosestMatch(p.x, p.y);
      outputArr[IX(p.x, p.y)] = match;
    }
    //println("\n");
    //for(int i = 0; i < pairCount; i++)
    //  print (pairs[i].x, pairs[i].y, " ");
    
    Arrays.fill(pairs, 0, pairCount, blankPair);
    pairCount = 0;
    if((x + y) % 20 == 0) {
      println(x, y);
    }
  }
}

void generateTexture() {
  int k = kernelSize / 2;
  //initializeTextureSingleCornerPixel(k);
  initializeTextureTopLeftPatch(12);
  iterateFillTopLeft(k);
  //iterateFillTopLeft(k);
  //iterateFillTopLeft(k);
  
  //initializeTextureCenterPatch(12);
  //iterateFillGrowCenter(3);
}

void draw() {
  loadPixels();
  //image(exampleImg, 0, 0);
  //copyImage(exampleImg.pixels, 3, 3, outputArr, outWidth, outHeight, kernelSize/2, kernelSize/2);
  println("begin gen");
  generateTexture();
  println("end gen");
  arrayCopy(outputArr, pixels);
  updatePixels();
  Arrays.fill(outputArr, INVALID_COLOR);
}

float[] generateGaussianKernel(int ksize, float sigma) {
  int half = ksize / 2;
  float[] kernel = new float[ksize * ksize];
  float sum = 0;
  
  // Compute kernel values
  for (int y = -half; y <= half; y++) {
    for (int x = -half; x <= half; x++) {
      int index = (y + half) * ksize + (x + half);
      //if(x == 0 && y == 0) {kernel[index] = 0.0; continue;}
      kernel[index] = gaussian(x, y, sigma);
      sum += kernel[index];
    }
  }

  // Normalize
  for (int i = 0; i < kernel.length; i++) {
    kernel[i] /= sum;
  }

  return kernel;
}

// Gaussian function
float gaussian(float x, float y, float sigma) {
  float coeff = 1.0 / (TWO_PI * sigma * sigma);
  float exponent = -(x * x + y * y) / (2 * sigma * sigma);
  return coeff * exp(exponent);
}

float colorDistance(color c1, color c2) {
  float r1 = red(c1), g1 = green(c1), b1 = blue(c1);
  float r2 = red(c2), g2 = green(c2), b2 = blue(c2);
  
  return dist(r1, g1, b1, r2, g2, b2);  // Processing's dist() function
}

void copyRegion(color[] src, int srcW, int srcH, int srcX, int srcY, int copyW, int copyH, 
                color[] dest, int destW, int destH, int destX, int destY) {
  for (int y = 0; y < copyH; y++) {
    for (int x = 0; x < copyW; x++) {
      int srcXPos = srcX + x;
      int srcYPos = srcY + y;
      int destXPos = destX + x;
      int destYPos = destY + y;

      // Ensure we are within bounds of both images
      if (srcXPos >= 0 && srcXPos < srcW && srcYPos >= 0 && srcYPos < srcH &&
          destXPos >= 0 && destXPos < destW && destYPos >= 0 && destYPos < destH) {
        
        int srcIndex = srcYPos * srcW + srcXPos;
        int destIndex = destYPos * destW + destXPos;

        dest[destIndex] = src[srcIndex]; // Copy pixel
      }
    }
  }
}

void shufflePairArray(Pair[] array, int pairCount) {
  for (int i = pairCount - 1; i > 0; i--) {
    int j = int(random(i + 1)); // Pick a random index from 0 to i
    // Swap array[i] and array[j]
    Pair temp = array[i];
    array[i] = array[j];
    array[j] = temp;
  }
}
