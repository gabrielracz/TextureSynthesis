import java.util.Arrays;

boolean shouldGen = true;
PImage exampleImg;
color[] outputArr;
int outWidth, outHeight;

int patchSize = 32;
int patchOverlap = 12;
color[] samplePatch = new color[patchSize * patchSize];
int numPatchSamples = 1024;

final color INVALID_COLOR = color(0, 0);
//final float MAX_COLOR_DIST = sqrt(255*255 * 3);
final float MAX_COLOR_DIST = 255*255 * 3;


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
  exampleImg = loadImage("building.png");
  exampleImg.loadPixels();
  initOutputArr(winWidth, winHeight);
  randomSeed(1337);
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

class CostMap {
  int h;
  int w;
  float[] map;
  float[] hmap;
  int[] cuts;
  int[] hcuts;
  
  CostMap(int h, int w) {
    this.w = w;
    this.h = h;
    this.map = new float[w * h];
    this.hmap = new float[w * h];
    this.cuts = new int[h]; // what column to cut at for each row
    this.hcuts = new int[h]; // what column to cut at for each row
    
    Arrays.fill(map, 0.0);
    Arrays.fill(hmap, 0.0);
  }
}

CostMap createCostMap(color[] patch, int outX, int outY) {
  CostMap costMap = new CostMap(patchSize, patchOverlap);
  if(outX > 0) {
    for(int y = 0; y < patchSize; y++) {
      for(int x = 0; x < patchOverlap; x++) {
        float cost = 0.0;
        int ix = (y + outY) * outWidth + (x + outX);
        if(ix < outputArr.length) 
          cost = colorDistance(patch[y * patchSize + x], outputArr[ix]);
        costMap.map[y * patchOverlap + x] = cost*cost;
      }
    }
  }
  return costMap;
}

CostMap createCostMapHoriz(color[] patch, int outX, int outY) {
  CostMap costMap = new CostMap(patchSize, patchOverlap);
  if(outY > 0) {
    for(int y = 0; y < patchOverlap; y++) {
      for(int x = 0; x < patchSize; x++) {
        float cost = 0.0;
        int ix = (y + outY) * outWidth + (x + outX);
        if(ix < outputArr.length) 
           cost = colorDistance(patch[y * patchSize + x], outputArr[ix]);
        costMap.map[x * patchOverlap + y] = cost*cost;
      }
    }
  }
  return costMap;
}

void drawCostMapVert(CostMap vcm, int outX, int outY) {
  for(int y = 0; y < vcm.h; y++) {
    for(int x = 0; x < vcm.w; x++) {
      float cost = vcm.map[y * vcm.w + x];
      float intensity = cost / MAX_COLOR_DIST;
      color col = color(intensity * 255.0);
      if (vcm.cuts[y] == x) {
        //col = color(255.0, 0.0, 0.0);
      } else {  
        //continue;
      }
      outputArr[(y + outY) * outWidth + (x + outX)] = col;
    }
  }
}

void drawCostMapHoriz(CostMap cm, int outX, int outY) {
  for(int y = 0; y < cm.w; y++) {
    for(int x = 0; x < cm.h; x++) {
      float cost = cm.map[x * cm.w + y];
      float intensity = cost / MAX_COLOR_DIST;
      color col = color(intensity * 255.0);
      if (cm.cuts[x] == y) {
        //col = color(255.0, 0.0, 0.0);
      } else {  
        //continue;
      }
      outputArr[(y + outY) * outWidth + (x + outX)] = col;
    }
  }
}

float getOverlapCost(CostMap cm) {
  float sum = 0;
  for(int i = 0; i < cm.map.length; i++) {
    sum += cm.map[i];
  }
  return sum;
}


float minCutCostMap(CostMap cm) {
  // Create a 2D array to store minimum costs
  float[][] minCost = new float[cm.h][cm.w];
  // Create a 2D array to store the column used to reach each cell
  int[][] prevCol = new int[cm.h][cm.w];
  
  // Initialize the first row with costs from the map
  for (int x = 0; x < cm.w; x++) {
    minCost[0][x] = cm.map[x];
    prevCol[0][x] = x; // Starting column
  }
  
  // Process each row from the second one to the bottom
  for (int y = 1; y < cm.h; y++) {
    for (int x = 0; x < cm.w; x++) {
      // Get current cell's cost
      float cellCost = cm.map[y * cm.w + x];
      
      // Initialize with a large value
      minCost[y][x] = Float.MAX_VALUE;
      
      // Check the three possible previous cells (left diagonal, above, right diagonal)
      int search = 1;
      for (int dx = -search; dx <= search; dx++) {
        int prevX = x + dx;
        
        // Skip if previous column is out of bounds
        if (prevX < 0 || prevX >= cm.w) continue;
        
        // Calculate total cost through this path
        float pathCost = minCost[y-1][prevX] + cellCost;
        
        // If this path is cheaper, update the minimum cost and previous column
        if (pathCost < minCost[y][x]) {
          minCost[y][x] = pathCost;
          prevCol[y][x] = prevX;
        }
      }
    }
  }
  
  // Find the column with minimum cost in the last row
  float minBottomCost = Float.MAX_VALUE;
  int minBottomCol = 0;
  
  for (int x = 0; x < cm.w; x++) {
    if (minCost[cm.h-1][x] < minBottomCost) {
      minBottomCost = minCost[cm.h-1][x];
      minBottomCol = x;
    }
  }
  
  // Backtrack to find the optimal path
  cm.cuts[cm.h-1] = minBottomCol; // Set the bottom row's cut
  
  for (int y = cm.h-1; y > 0; y--) {
    // The previous column is determined by the prevCol array
    cm.cuts[y-1] = prevCol[y][cm.cuts[y]];
  }
  return minBottomCost;
}

void drawPatch(color[] patch, CostMap vcm, CostMap hcm, int outX, int outY) {
  for(int py = 0; py < patchSize; py++) {
    for(int px = vcm.cuts[py]; px < patchSize; px++) {
      if(py < hcm.cuts[px]) continue;
      int ix = (py + outY) * outWidth + (px + outX);
      if(ix >= outputArr.length || (px + outX) >= outWidth) continue;
      outputArr[(py + outY) * outWidth + (px + outX)] = patch[py * patchSize + px];
    }
  }
}

void generateTexture() {
  //initializeTextureTopLeft();
  float lowestCost = Float.MAX_VALUE;
  color[] bestPatch = new color[samplePatch.length];
  CostMap bestVCM = new CostMap(patchSize, patchOverlap);
  CostMap bestHCM = new CostMap(patchSize, patchOverlap);
        
  int patchStep = patchSize - patchOverlap;
  int numTilesX = floor(outWidth / (patchStep));
  int numTilesY = floor(outHeight / (patchStep));
  //int numTilesX = 6;
  //int numTilesY = 6;
  
  for(int ty = 0; ty < numTilesY; ty++) {
    for(int tx = 0; tx < numTilesX; tx++) {
      lowestCost = Float.MAX_VALUE;
      for(int i = 0; i < numPatchSamples; i++) {
        getRandomPatch(samplePatch);
        CostMap costMap = createCostMap(samplePatch, tx*patchStep, ty*patchStep);
        CostMap costMapHoriz = createCostMapHoriz(samplePatch, tx*patchStep, ty*patchStep);
        float overlapCost = getOverlapCost(costMap);
        overlapCost += getOverlapCost(costMapHoriz);
        if(overlapCost < lowestCost) {
          arrayCopy(samplePatch, bestPatch);
          lowestCost = overlapCost;
          arrayCopy(costMap.map, bestVCM.map);
          arrayCopy(costMapHoriz.map, bestHCM.map);
        }
      }
      
      minCutCostMap(bestVCM);
      minCutCostMap(bestHCM);
      
      drawPatch(bestPatch, bestVCM, bestHCM, tx*patchStep, ty*patchStep);
      //drawCostMapVert(bestVCM, tx*patchStep, ty*patchStep);
      //drawCostMapHoriz(bestHCM, tx*patchStep, ty*patchStep);
    }
  }
}

void draw() {
  if(!shouldGen) {
    delay(500);
    return;
  }
  
  loadPixels();
  generateTexture();
  arrayCopy(outputArr, pixels);
  updatePixels();
  shouldGen = false;
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

float colorDistance(color c1, color c2) {
  float r1 = red(c1), g1 = green(c1), b1 = blue(c1);
  float r2 = red(c2), g2 = green(c2), b2 = blue(c2);
  
  return dist(r1, g1, b1, r2, g2, b2);  // Processing's dist() function
}

void keyPressed() {
   shouldGen = true;
}
