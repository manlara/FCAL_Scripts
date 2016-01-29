#include <iostream>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>
#include <map>
#include <stdio.h>
#include <algorithm>
#include <stdlib.h>
#include <utility>

#include "TString.h"
#include "TH1F.h"
#include "TH2I.h"
#include "TCanvas.h"
#include "TMath.h"

vector<string> parseString(string text, char delimeter){
  
  vector<string> vec_str;
  string::size_type start_pos = 0, end_pos;
  do{
    end_pos = text.find(delimeter, start_pos);
    if (end_pos != string::npos){
      vec_str.push_back(text.substr(start_pos,end_pos-start_pos));
      start_pos = end_pos + 1;
    } else{
      vec_str.push_back(text.substr(start_pos));
    }
  }
  while(end_pos != string::npos);
  
  return vec_str;
}

pair<int,int> getCoordinate(string name){
  vector<string> pString = parseString(name, ':');
  int x = TString(pString[2]).Atoi();
  int y = TString(pString[3]).Atoi();
  return make_pair(x, y);
}

TH2I* hist_2d(map<pair<int,int>, double> pattern, double xmin=-30, double xmax=30, double ymin=-30, double ymax=30){
  TH2I* hist = new TH2I("hist", "Pattern", (int) xmax-xmin, xmin, xmax, (int) ymax-ymin, ymin, ymax);
  
  for (map<pair<int,int>, double>::const_iterator iter=pattern.begin(); iter!=pattern.end(); ++iter){
    hist->Fill(iter->first.first,iter->first.second, iter->second);
  }
  return hist;
}

void checkPatterns(TString filename){
  string name;
  int active;
  double hv;
  
  map<pair<int,int>, double> pattern_hv;
  
  string line;
  ifstream myfile;
  myfile.open(filename.Data());
  if (myfile.is_open())
  {
    while( getline (myfile,line) )
    {
      std::istringstream iss(line);
      iss >> name >> active >> hv;
      
      if (!TString(name).Contains("FCAL:hv")) continue;
      
      pair<int,int> coord =getCoordinate(name);
      pattern_hv[coord] = hv;
    }
  }
  
  hist_2d(pattern_hv)->Draw();
}