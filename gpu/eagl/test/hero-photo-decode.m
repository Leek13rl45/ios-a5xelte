#import <Foundation/Foundation.h>
#import <ImageIO/ImageIO.h>
#import <CoreGraphics/CoreGraphics.h>
#include <dlfcn.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <unistd.h>
#include <stdio.h>

static void register_decoder(void) {
 void *codec=dlopen("/System/Library/VideoCodecs/VCPHEVC.videocodec",RTLD_NOW|RTLD_LOCAL);
 void *vt=dlopen("/System/Library/Frameworks/VideoToolbox.framework/VideoToolbox",RTLD_NOW|RTLD_GLOBAL);
 void *create=codec?dlsym(codec,"HEVCVideoDecoder_CreateInstance"):NULL;
 int (*reg)(uint32_t,CFDictionaryRef,void *)=vt?dlsym(vt,"VTRegisterVideoDecoderWithInfo"):NULL;
 CFStringRef *idKey=vt?dlsym(vt,"kVTVideoDecoderList_DecoderID"):NULL;
 CFStringRef *nameKey=vt?dlsym(vt,"kVTVideoDecoderList_DecoderName"):NULL;
 CFStringRef *hwKey=vt?dlsym(vt,"kVTVideoDecoderList_IsHardwareAccelerated"):NULL;
 printf("decode-probe: codec %d create %d register %d keys %d/%d/%d\n",codec!=NULL,create!=NULL,reg!=NULL,idKey!=NULL,nameKey!=NULL,hwKey!=NULL);
 if(!create||!reg||!idKey||!*idKey||!nameKey||!*nameKey||!hwKey||!*hwKey)return;
 const void *keys[]={*idKey,*nameKey,*hwKey},*values[]={CFSTR("com.herolte.decode-probe.hevc.vcp"),CFSTR("VCPHEVC diagnostic software decoder"),kCFBooleanFalse};
 CFDictionaryRef info=CFDictionaryCreate(NULL,keys,values,3,&kCFTypeDictionaryKeyCallBacks,&kCFTypeDictionaryValueCallBacks);
 if(info){printf("decode-probe: software decoder registration %d\n",reg('hvc1',info,create));CFRelease(info);}
}
int main(int argc,char **argv){@autoreleasepool{
 setvbuf(stdout,NULL,_IOLBF,0);
 if(argc!=2|| (strcmp(argv[1],"baseline")&&strcmp(argv[1],"registered")))return 2;
 if(!strcmp(argv[1],"registered"))register_decoder();
 NSString *path=@"/private/var/mobile/Media/DCIM/100APPLE/IMG_0003.HEIC";
 CGImageSourceRef source=CGImageSourceCreateWithURL((__bridge CFURLRef)[NSURL fileURLWithPath:path],NULL);
 if(!source){printf("decode-probe: no source\n");return 3;}
 CGImageRef image=CGImageSourceCreateImageAtIndex(source,0,(__bridge CFDictionaryRef)@{(__bridge NSString *)kCGImageSourceShouldCache:@NO});
 if(!image){printf("decode-probe: image failed status %d\n",(int)CGImageSourceGetStatusAtIndex(source,0));CFRelease(source);return 4;}
 size_t w=CGImageGetWidth(image),h=CGImageGetHeight(image);
 printf("decode-probe: image %zux%zu depth %zu\n",w,h,CGImageGetBitsPerComponent(image));
 if(w!=4032||h!=3024){CGImageRelease(image);CFRelease(source);return 5;}
 NSString *file=[NSString stringWithFormat:@"/private/var/herolte/decode-%s.rgba",argv[1]];
 size_t size=w*h*4;int fd=open(file.fileSystemRepresentation,O_RDWR|O_CREAT|O_TRUNC,0644);
 void *pixels=MAP_FAILED;
 if(fd>=0&&!ftruncate(fd,(off_t)size))pixels=mmap(NULL,size,PROT_READ|PROT_WRITE,MAP_SHARED,fd,0);
 if(pixels==MAP_FAILED){if(fd>=0)close(fd);CGImageRelease(image);CFRelease(source);return 6;}
 CGColorSpaceRef space=CGColorSpaceCreateDeviceRGB();
 CGContextRef bitmap=CGBitmapContextCreate(pixels,w,h,8,w*4,space,kCGImageAlphaPremultipliedLast|kCGBitmapByteOrder32Big);
 if(bitmap){CGContextDrawImage(bitmap,CGRectMake(0,0,w,h),image);CGContextRelease(bitmap);}
 uint64_t sum[4]={0};size_t lit=0;const uint8_t *b=pixels;
 for(size_t i=0;i<w*h;i+=17){lit+=(b[4*i]|b[4*i+1]|b[4*i+2])!=0;for(unsigned c=0;c<4;c++)sum[c]+=b[4*i+c];}
 printf("decode-probe: bitmap %d samples-lit %zu sums %llu/%llu/%llu/%llu\n",bitmap!=NULL,lit,(unsigned long long)sum[0],(unsigned long long)sum[1],(unsigned long long)sum[2],(unsigned long long)sum[3]);
 msync(pixels,size,MS_SYNC);munmap(pixels,size);fsync(fd);close(fd);CGColorSpaceRelease(space);CGImageRelease(image);CFRelease(source);return bitmap?0:7;
}}
