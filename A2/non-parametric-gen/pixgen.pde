import java.util.Arrays;

PImage exampleImg;
color[] outputArr;
int outWidth, outHeight;

float errorThreshold = 0.1;
color[] candidateMatches;
int kernelSize = 7;
float sigma = float(kernelSize) / 6.4; 
float[] gaussianWeights = generateGaussianKernel(kernelSize, sigma);
boolean[] dummyValidMask;

final color INVALID_COLOR = color(0, 0);


int IX(int x, int y) { return y * outWidth + x; }


void initOutputArr(int w, int h) {
  outputArr = new color[w * h];
  outWidth = w;
  outHeight = h;
  Arrays.fill(outputArr, INVALID_COLOR);
}

int winWidth = 512, winHeight = 512;

void settings() {
  size(winWidth, winHeight);
}

void setup() {
  exampleImg = loadImage("scales.png");
  exampleImg.loadPixels();
  initOutputArr(winWidth, winHeight);
  candidateMatches = new color[exampleImg.pixels.length];
  println(gaussianWeights);
}

float computeSimilarity(int exX, int exY, float[] weights, boolean[] validMask, int outX, int outY) {
  int k = kernelSize / 2;
  //int validCount = 0;
  float accumScore = 0.0;
  for(int i = 0; i < kernelSize; i++) {
    for(int j = 0; j < kernelSize; j++) {
      int y = exY + (i - k);
      int x = exX + (j - k);
      color sample = exampleImg.pixels[y * exampleImg.width + x]; //<>//
      
      int oy = outY + (i - k);
      int ox = outX + (j - k);
      color cmp = outputArr[oy * outWidth + ox];
      
      float d = colorDistance(sample, cmp);
      float w = weights[i * kernelSize + j];
      //float v = (validMask[i * kernelSize + j]) ? 1.0 : 0.0;
      float v = (cmp == INVALID_COLOR) ? 0.0 : 1.0;

      float result = d * w * v;
      
      accumScore += result;
    }
  }
  return accumScore;
}

color findClosestMatch(int outX, int outY) {
  int k = kernelSize / 2;
  Arrays.fill(candidateMatches, INVALID_COLOR);
  int matches = 0;
  for(int y = k; y < exampleImg.height - k; y++) {
    for(int x = k; x < exampleImg.width - k; x++) {
      float score = computeSimilarity(x, y, gaussianWeights, dummyValidMask, outX, outY);
      if(score < errorThreshold) {
        candidateMatches[matches] = exampleImg.pixels[y * exampleImg.width + x];
        matches++;
      }
    }
  }
  color randPick = candidateMatches[floor(random(matches))];
  return randPick;
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

void generateTexture() {
  //int kernelSize = 3;
  int k = kernelSize / 2;
  
  // sample a random pixel from original examplar and place it at the starting point in the output
  int ry = floor(random(exampleImg.height));
  int rx = floor(random(exampleImg.width));
  color randInitialColor = exampleImg.pixels[ry * exampleImg.width + rx];
  outputArr[IX(k, k)] = randInitialColor;

  for(int y = k + 1; y < outWidth - k; y++) {
    for(int x = k; x < outWidth - k; x++) {
      color match = findClosestMatchMonte(x, y, 400);
      outputArr[IX(x, y)] = match;
    }
    if(y % 50 == 0) {
        println(y);
    }
  }
}

void draw() {
  loadPixels();
  //image(exampleImg, 0, 0);
  //copyImage(exampleImg.pixels, exampleImg.width, exampleImg.height, outputArr, outWidth, outHeight);
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
      if(x == 0 && y == 0) {kernel[index] = 0.0; continue;}
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

void copyImage(color[] src, int srcW, int srcH, color[] dest, int destW, int destH) {
  for (int y = 0; y < srcH; y++) {
    for (int x = 0; x < srcW; x++) {
      int srcIndex = y * srcW + x;
      int destIndex = y * destW + x;  // Copy to top-left corner
      dest[destIndex] = src[srcIndex];
    }
  }
}
