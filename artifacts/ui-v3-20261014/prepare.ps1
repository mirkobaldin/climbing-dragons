param([switch]$AvailableOnly)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Drawing.Drawing2D;
using System.Runtime.InteropServices;
public static class V3Export {
 public static void Save(string source,string target,int w,int h,int sx,int ex) {
  using(var src=new Bitmap(source)) {
   int x0=src.Width,y0=src.Height,x1=0,y1=0;
   var bits=src.LockBits(new Rectangle(0,0,src.Width,src.Height),ImageLockMode.ReadOnly,PixelFormat.Format32bppArgb);
   byte[] buf=new byte[bits.Stride*src.Height];Marshal.Copy(bits.Scan0,buf,0,buf.Length);
   for(int y=0;y<src.Height;y++)for(int x=0;x<src.Width;x++)if(buf[y*bits.Stride+x*4+3]>=8){x0=Math.Min(x0,x);y0=Math.Min(y0,y);x1=Math.Max(x1,x);y1=Math.Max(y1,y);}
   src.UnlockBits(bits);
   if(x1<=x0||y1<=y0)throw new Exception("PNG vuoto: "+source);
   using(var dst=new Bitmap(w,h,PixelFormat.Format32bppArgb)) {
    using(var g=Graphics.FromImage(dst))using(var attr=new ImageAttributes()){
     g.Clear(Color.Transparent);g.CompositingMode=CompositingMode.SourceCopy;g.InterpolationMode=InterpolationMode.HighQualityBicubic;g.PixelOffsetMode=PixelOffsetMode.HighQuality;
     attr.SetWrapMode(WrapMode.TileFlipXY);
     var rect=new Rectangle(4,4,w-8,h-8);
     if(w==h){double scale=Math.Min((w-24.0)/(x1-x0+1),(h-24.0)/(y1-y0+1));int dw=(int)Math.Round((x1-x0+1)*scale),dh=(int)Math.Round((y1-y0+1)*scale);rect=new Rectangle((w-dw)/2,(h-dh)/2,dw,dh);}
     g.DrawImage(src,rect,x0,y0,x1-x0+1,y1-y0+1,GraphicsUnit.Pixel,attr);
    }
    // Centro uniforme per l'allungamento 9-slice: stesso campione per tutta la riga.
    if(sx>0)for(int y=0;y<h;y++){
     Color c=dst.GetPixel(w/2,y);
     for(int x=sx-16;x<ex+16;x++){
      Color old=dst.GetPixel(x,y);double t=x<sx?(x-sx+16)/16.0:x>=ex?(ex+15-x)/16.0:1;
      dst.SetPixel(x,y,Color.FromArgb((int)(old.A+(c.A-old.A)*t),(int)(old.R+(c.R-old.R)*t),(int)(old.G+(c.G-old.G)*t),(int)(old.B+(c.B-old.B)*t)));
     }
    }
    dst.Save(target,ImageFormat.Png);
   }
  }
 }
 public static string Check(string path){using(var im=new Bitmap(path)){int clear=0,edge=0;for(int y=0;y<im.Height;y++)for(int x=0;x<im.Width;x++){int a=im.GetPixel(x,y).A;if(a==0)clear++;if((x==0||y==0||x==im.Width-1||y==im.Height-1)&&a>0)edge++;}return "{\"width\":"+im.Width+",\"height\":"+im.Height+",\"transparentPixels\":"+clear+",\"edgePixels\":"+edge+"}";}}
}
'@
$jobs=Get-Content -LiteralPath "$PSScriptRoot/manifest.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$sources=Get-Content -LiteralPath "$PSScriptRoot/sources.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$report=@()
foreach($j in $jobs){
 $source=@($sources | Where-Object name -eq $j.name)
 if($source.Count -eq 0){if($AvailableOnly){continue};throw "Sorgente mancante: $($j.name)"}
 $dest=Join-Path $PSScriptRoot ($j.name+'.png')
 $sx=0;$ex=0;if($j.slice){$sx=$j.slice[0];$ex=$j.slice[2]}
 [V3Export]::Save($source[-1].source,$dest,$j.width,$j.height,$sx,$ex)
 $check=[V3Export]::Check($dest)|ConvertFrom-Json
 if($check.edgePixels -gt 0 -or $check.transparentPixels -eq 0){throw "Alpha non valido: $($j.name)"}
 $report+=@{name=$j.name;check=$check}
}
$report | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath "$PSScriptRoot/png-checks.json" -Encoding UTF8
Write-Output "PNG esportati e verificati: $($report.Count)"
