param([switch]$ValidateOnly, [switch]$AvailableOnly)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Drawing.Drawing2D;
using System.Runtime.InteropServices;
public static class V2Png {
  // Normalizzazione geometrica dei PNG generati: ritaglio alpha e misura richiesta.
  // Esportazione del canale alpha secondo i valori numerici della specifica.
  public static void Prepare(string input, string output, int w, int h, bool pressed, float alphaGain, bool whiteMask) {
    using(var src = new Bitmap(input)) {
      int x0=src.Width,y0=src.Height,x1=0,y1=0;
      var bd=src.LockBits(new Rectangle(0,0,src.Width,src.Height),ImageLockMode.ReadOnly,PixelFormat.Format32bppArgb);
      byte[] bytes=new byte[bd.Stride*src.Height]; Marshal.Copy(bd.Scan0,bytes,0,bytes.Length);
      for(int y=0;y<src.Height;y++) for(int x=0;x<src.Width;x++) {
        if(bytes[y*bd.Stride+x*4+3]<8) continue;
        x0=Math.Min(x0,x);y0=Math.Min(y0,y);x1=Math.Max(x1,x);y1=Math.Max(y1,y);
      }
      src.UnlockBits(bd);
      if(x1<=x0||y1<=y0) throw new Exception("Immagine vuota: "+input);
      using(var dst=new Bitmap(w,h,PixelFormat.Format32bppArgb))
      using(var g=Graphics.FromImage(dst))
      using(var attr=new ImageAttributes()) {
        g.CompositingMode=CompositingMode.SourceCopy;
        g.InterpolationMode=InterpolationMode.HighQualityBicubic;
        g.PixelOffsetMode=PixelOffsetMode.HighQuality;
        g.Clear(Color.Transparent); attr.SetWrapMode(WrapMode.TileFlipXY);
        int margin=w==512&&h==256?10:4;
        int dy=pressed?2:0;
        // La riserva di 2 px in basso consente la pressione senza tagliare il bordo.
        int dh=h-margin*2-(w!=h&&h!=256?2:0);
        var matrix=new ColorMatrix();matrix.Matrix33=alphaGain;
        if(whiteMask){matrix.Matrix00=0;matrix.Matrix11=0;matrix.Matrix22=0;matrix.Matrix40=1;matrix.Matrix41=1;matrix.Matrix42=1;}
        attr.SetColorMatrix(matrix);
        // La maschera delle rune conserva un rettangolo registrato sul piano del piedistallo.
        Rectangle target=whiteMask?new Rectangle(70,16,372,124):new Rectangle(margin,margin+dy,w-margin*2,dh);
        g.DrawImage(src,target,x0,y0,x1-x0+1,y1-y0+1,GraphicsUnit.Pixel,attr);
        // Il centro richiesto e' una striscia verticale ripetibile: elimina la variazione
        // orizzontale residua della generazione, senza introdurre disegni o nuovi colori.
        if(h==160||h==112){
          int left=h==160?64:56,top=h==160?48:36;
          for(int py=top;py<h-top;py++){
            Color row=dst.GetPixel(w/2,py);
            for(int px=left;px<w-left;px++)dst.SetPixel(px,py,row);
          }
        }
        // Elimina soltanto residui alpha invisibili da 1/255 dell'esportazione.
        for(int py=0;py<h;py++)for(int px=0;px<w;px++){Color p=dst.GetPixel(px,py);if(p.A<=1)dst.SetPixel(px,py,Color.Transparent);}
        dst.Save(output,ImageFormat.Png);
      }
    }
  }
  static double Channel(byte v){double s=v/255.0;return s<=0.04045?s/12.92:Math.Pow((s+0.055)/1.055,2.4);}
  public static string Inspect(string path,int sx,int sy,int ex,int ey){
    using(var im=new Bitmap(path)){
      int zero=0,partial=0,solid=0,edge=0,amin=255,amax=0; double minContrast=21,maxRowVariation=0;
      for(int y=0;y<im.Height;y++){
        double rmin=255,rmax=0,gmin=255,gmax=0,bmin=255,bmax=0;
        for(int x=0;x<im.Width;x++){
          Color c=im.GetPixel(x,y);
          if(c.A==0)zero++;else if(c.A==255)solid++;else partial++;
          if((x==0||y==0||x==im.Width-1||y==im.Height-1)&&c.A>0)edge++;
          if(x>=sx&&x<ex&&y>=sy&&y<ey){
            amin=Math.Min(amin,c.A);amax=Math.Max(amax,c.A);
            // Caso peggiore: composizione sul bianco, compreso l'alpha del PNG.
            double a=c.A/255.0;
            byte cr=(byte)Math.Round(c.R*a+255*(1-a)),cg=(byte)Math.Round(c.G*a+255*(1-a)),cb=(byte)Math.Round(c.B*a+255*(1-a));
            double lum=0.2126*Channel(cr)+0.7152*Channel(cg)+0.0722*Channel(cb);
            minContrast=Math.Min(minContrast,1.05/(lum+0.05));
            rmin=Math.Min(rmin,c.R);rmax=Math.Max(rmax,c.R);gmin=Math.Min(gmin,c.G);gmax=Math.Max(gmax,c.G);bmin=Math.Min(bmin,c.B);bmax=Math.Max(bmax,c.B);
          }
        }
        if(y>=sy&&y<ey)maxRowVariation=Math.Max(maxRowVariation,Math.Max(rmax-rmin,Math.Max(gmax-gmin,bmax-bmin)));
      }
      return String.Format(System.Globalization.CultureInfo.InvariantCulture,"{{\"width\":{0},\"height\":{1},\"transparent\":{2},\"partial\":{3},\"opaque\":{4},\"edgePixels\":{5},\"centerAlphaMin\":{6},\"centerAlphaMax\":{7},\"whiteContrastMin\":{8:F2},\"horizontalVariationMax\":{9}}}",im.Width,im.Height,zero,partial,solid,edge,amin,amax,minContrast,maxRowVariation);
    }
  }
}
'@
$jobs=Get-Content -LiteralPath "$PSScriptRoot/manifest.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$sources=Get-Content -LiteralPath "$PSScriptRoot/sources.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$report=@()
foreach($j in $jobs){
  $dest=Join-Path $PSScriptRoot ($j.name+'.png')
  if(-not $ValidateOnly){
    $matches=@($sources|Where-Object name -eq $j.name)
    if($matches.Count -eq 0 -and $AvailableOnly){continue}
    $source=$matches[-1].source
    if(-not $source){throw "Sorgente mancante: $($j.name)"}
    $gain=if($j.name -eq 'card_glass_v2'){0.875}elseif($j.name -eq 'pedestal_runes_v2'){0.504}else{1.0}
    [V2Png]::Prepare($source,$dest,$j.width,$j.height,$j.name.EndsWith('_pressed'),$gain,($j.name -eq 'pedestal_runes_v2'))
  }
  $slice=if($j.slice){$j.slice}else{@(128,64,384,192)}
  $r=[V2Png]::Inspect($dest,$slice[0],$slice[1],$slice[2],$slice[3])|ConvertFrom-Json
  $r|Add-Member name $j.name
  $r|Add-Member passed ($r.width -eq $j.width -and $r.height -eq $j.height -and $r.edgePixels -eq 0 -and $r.transparent -gt 0)
  if($j.state){$r.passed=$r.passed -and $r.whiteContrastMin -ge 4.5 -and $r.horizontalVariationMax -eq 0}
  if($j.name -eq 'card_glass_v2'){$r.passed=$r.passed -and $r.centerAlphaMin -ge 179 -and $r.centerAlphaMax -le 204}
  if($j.name -eq 'card_item_v2'){$r.passed=$r.passed -and $r.centerAlphaMax -eq 0}
  $report+=$r
}
$report|ConvertTo-Json -Depth 5|Set-Content -LiteralPath "$PSScriptRoot/validation.json" -Encoding UTF8
$report|Select-Object name,width,height,centerAlphaMin,centerAlphaMax,whiteContrastMin,horizontalVariationMax,passed|Format-Table -AutoSize
if(@($report|Where-Object passed -eq $false).Count){throw 'Verifica dei PNG fallita'}
