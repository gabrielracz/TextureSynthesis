import java.util.Arrays;

PImage exampleImg;
color[] outputArr;
int outWidth, outHeight;

int patchSize = 32;
int patchOverlap = 8;
color[] samplePatch = new color[patchSize * patchSize];

final color INVALID_COLOR = color(0, 0);


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
  //noLoop();
}


void getRandomPatch(color[] patch) {
  Arrays.fill(patch, INVALID_COLOR);
  int rx = floor(random(exampleImg.width - patchSize));
  int ry = floor(random(exampleImg.height - patchSize));
  for(int i = 0; i < patchSize; i++) {
    for(int j = 0; j < patchSize; j++) {
      patch[i * patchSize + j] = exampleImg.pixels[(ry + i) * exampleImg.width + (rx + j)];
    }
  }
}

void initializeTextureTopLeft() {
  getRandomPatch(samplePatch);
  copyRegion(samplePatch, patchSize, patchSize, 0, 0, patchSize, patchSize,
             outputArr, outWidth, outHeight, 0, 0);
}


void generateTexture() {
  initializeTextureTopLeft();
  
  getRandomPatch(samplePatch);
  copyRegion(samplePatch, patchSize, patchSize, 0, 0, patchSize, patchSize,
             outputArr, outWidth, outHeight, patchSize, 0);
}

void draw() {
  loadPixels();
  generateTexture();
  arrayCopy(outputArr, pixels);
  updatePixels();
  delay(1000);
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
