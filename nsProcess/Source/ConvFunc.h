/*****************************************************************
 *           Conversion functions header v1.9                    *
 *                                                               *
 * 2006 Shengalts Aleksander aka Instructor (Shengalts@mail.ru)  *
 *                                                               *
 *                                                               *
 *Functions (ALLCONVFUNC):                                       *
 * xatoi, xatoiW, xitoa, xitoaW, xatoui, xatouiW,                *
 * xuitoa, xuitoaW, xatoi64, xatoi64W, xi64toa, xi64toaW,        *
 * hex2dec, hex2decW, dec2hex, dec2hexW                          *
 *                                                               *
 *Special functions (ALLCONVFUNCS):                              *
 * str2hex, hex2str                                              *
 *                                                               *
 *****************************************************************/

#ifndef _CONVFUNC_
#define _CONVFUNC_ 

int xatoi(char *str);
int xatoiW(wchar_t *wstr);
char* xitoa(int number, char *str, int width);
wchar_t* xitoaW(int number, wchar_t *wstr, int width);
unsigned int xatoui(char *str);
unsigned int xatouiW(wchar_t *wstr);
char* xuitoa(unsigned int number, char *str, int width);
wchar_t* xuitoaW(unsigned int number, wchar_t *wstr, int width);
__int64 xatoi64(char *str);
__int64 xatoi64W(wchar_t *wstr);
char* xi64toa(__int64 number, char *str, int width);
wchar_t* xi64toaW(__int64 number, wchar_t *wstr, int width);
int hex2dec(char *hex);
int hex2decW(wchar_t *whex);
void dec2hex(unsigned int dec, char *hex, BOOL lowercase, unsigned int width);
void dec2hexW(unsigned int dec, wchar_t *whex, BOOL lowercase, unsigned int width);

void str2hex(unsigned char *str, char *hex, BOOL lowercase, unsigned int bytes);
void hex2str(char *hex, char *str);

#endif

/********************************************************************
 *
 *  xatoi
 *
 *Converts string to int.
 *
 *[in]  char *str   -string number
 *
 *Returns: integer
 *
 *Examples:
 *  xatoi("45") == 45;
 *  xatoi("  -0045:value") == -45;
 ********************************************************************/
#if defined xatoi || defined ALLCONVFUNC
#define xatoi_INCLUDED
#undef xatoi
int xatoi(char *str)
{
  int nNumber=0;
  BOOL bMinus=FALSE;

  while (*str == ' ')
    ++str;
  if (*str == '+')
    ++str;
  else if (*str == '-')
  {
    bMinus=TRUE;
    ++str;
  }
  for (; *str != '\0' && *str >= '0' && *str <= '9'; ++str)
    nNumber=(nNumber * 10) + (*str - '0');
  if (bMinus == TRUE)
    nNumber=0 - nNumber;
  return nNumber;
}
#endif

/********************************************************************
 *
 *  xatoiW
 *
 *Converts unicode string to int.
 *
 *[in]  wchar_t *wstr   -string number
 *
 *Returns: integer
 *
 *Examples:
 *  xatoiW(L"45") == 45;
 *  xatoiW(L"  -0045:value") == -45;
 ********************************************************************/
#if defined xatoiW || defined ALLCONVFUNC
#define xatoiW_INCLUDED
#undef xatoiW
int xatoiW(wchar_t *wstr)
{
  int nNumber=0;
  BOOL bMinus=FALSE;

  while (*wstr == ' ')
    ++wstr;
  if (*wstr == '+')
    ++wstr;
  else if (*wstr == '-')
  {
    bMinus=TRUE;
    ++wstr;
  }
  for (; *wstr != '\0' && *wstr >= '0' && *wstr <= '9'; ++wstr)
    nNumber=(nNumber * 10) + (*wstr - '0');
  if (bMinus == TRUE)
    nNumber=0 - nNumber;
  return nNumber;
}
#endif

/********************************************************************
 *
 *  xitoa   [API: wsprintf(szResult, "%d", 45)]
 *
 *Converts int to string.
 *
 *[in]   int number   -integer
 *[out]  char *str    -string number
 *[in]   int width    -minimum number of characters to the output
 *
 *Returns: a pointer to string
 *
 *Examples:
 *  xitoa(45, szResult, 0);   //szResult == "45"
 *  xitoa(-45, szResult, 0);  //szResult == "-45"
 *  xitoa(45, szResult, 4);   //szResult == "0045"
 ********************************************************************/
#if defined xitoa || defined ALLCONVFUNC
#define xitoa_INCLUDED
#undef xitoa
char* xitoa(int number, char *str, int width)
{
  char tmp[128];
  int a=0;
  int b=0;
  *tmp = 0;

  if (number == 0)
  {
    str[0]='0';
    --width;
    b=1;
  }
  else if (number < 0)
  {
    str[0]='-';
    number=0 - number;
    --width;
    b=1;
  }
  for (tmp[a]='\0'; number != 0; ++a)
  {
    tmp[a]=(number % 10) + '0';
    number=number / 10;
  }
  if (a < width)
  do
  {
	tmp[a]='0';
  } while (++a<width);
  for (--a; a >= 0; --a, ++b) str[b]=tmp[a];

  str[b]='\0';
  return str;
}
#endif

/********************************************************************
 *
 *  xitoaW   [API: wsprintfW(wszResult, L"%d", 45)]
 *
 *Converts int to unicode string.
 *
 *[in]   int number      -integer
 *[out]  wchar_t *wstr   -unicode string number
 *[in]   int width       -minimum number of characters to the output
 *
 *Returns: a pointer to unicode string
 *
 *Examples:
 *  xitoaW(45, wszResult, 0);   //wszResult == L"45"
 *  xitoaW(-45, wszResult, 0);  //wszResult == L"-45"
 *  xitoaW(45, wszResult, 4);   //wszResult == L"0045"
 ********************************************************************/
#if defined xitoaW || defined ALLCONVFUNC
#define xitoaW_INCLUDED
#undef xitoaW
wchar_t* xitoaW(int number, wchar_t *wstr, int width)
{
  wchar_t wtmp[128]=L"";
  int a=0;
  int b=0;

  if (number == 0)
  {
    wstr[0]='0';
    --width;
    b=1;
  }
  else if (number < 0)
  {
    wstr[0]='-';
    number=0 - number;
    --width;
    b=1;
  }
  for (wtmp[a]='\0'; number != 0; ++a)
  {
    wtmp[a]=(number % 10) + '0';
    number=number / 10;
  }
  for (; width > a; ++a) wtmp[a]='0';
  for (--a; a >= 0; --a, ++b) wstr[b]=wtmp[a];

  wstr[b]='\0';
  return wstr;
}
#endif

/********************************************************************
 *
 *  xatoui
 *
 *Converts string to unsigned int.
 *
 *[in]  char *str   -string number
 *
 *Returns: unsigned integer
 *
 *Examples:
 *  xatoui("45") == 45;
 *  xatoui("  -0045:value") == 0;
 ********************************************************************/
#if defined xatoui || defined ALLCONVFUNC
#define xatoui_INCLUDED
#undef xatoui
unsigned int xatoui(char *str)
{
  unsigned int nNumber=0;

  while (*str == ' ')
    ++str;
  if (*str == '+')
    ++str;
  else if (*str == '-')
    return 0;
  for (; *str != '\0' && *str >= '0' && *str <= '9'; ++str)
    nNumber=(nNumber * 10) + (*str - '0');
  return nNumber;
}
#endif

/********************************************************************
 *
 *  xatouiW
 *
 *Converts unicode string to unsigned int.
 *
 *[in]  wchar_t *wstr   -unicode string number
 *
 *Returns: unsigned integer
 *
 *Examples:
 *  xatouiW(L"45") == 45;
 *  xatouiW(L"  -0045:value") == 0;
 ********************************************************************/
#if defined xatouiW || defined ALLCONVFUNC
#define xatouiW_INCLUDED
#undef xatouiW
unsigned int xatouiW(wchar_t *wstr)
{
  unsigned int nNumber=0;

  while (*wstr == ' ')
    ++wstr;
  if (*wstr == '+')
    ++wstr;
  else if (*wstr == '-')
    return 0;
  for (; *wstr != '\0' && *wstr >= '0' && *wstr <= '9'; ++wstr)
    nNumber=(nNumber * 10) + (*wstr - '0');
  return nNumber;
}
#endif

/********************************************************************
 *
 *  xuitoa
 *
 *Converts unsigned int to string.
 *
 *[in]   unsigned int number   -unsigned integer
 *[out]  char *str             -string number
 *[in]   int width             -minimum number of characters to the output
 *
 *Returns: a pointer to string
 *
 *Examples:
 *  xuitoa(45, szResult, 0);   //szResult == "45"
 *  xuitoa(45, szResult, 4);   //szResult == "0045"
 ********************************************************************/
#if defined xuitoa || defined ALLCONVFUNC
#define xuitoa_INCLUDED
#undef xuitoa
char* xuitoa(unsigned int number, char *str, int width)
{
  char tmp[128]="";
  int a=0;
  int b=0;

  if (number == 0)
  {
    str[0]='0';
    --width;
    b=1;
  }
  for (tmp[a]='\0'; number != 0; ++a)
  {
    tmp[a]=(number % 10) + '0';
    number=number / 10;
  }
  for (; width > a; ++a) tmp[a]='0';
  for (--a; a >= 0; --a, ++b) str[b]=tmp[a];

  str[b]='\0';
  return str;
}
#endif

/********************************************************************
 *
 *  xuitoaW
 *
 *Converts unsigned int to unicode string.
 *
 *[in]   unsigned int number   -unsigned integer
 *[out]  wchar_t *wstr         -unicode string number
 *[in]   int width             -minimum number of characters to the output
 *
 *Returns: a pointer to unicode string
 *
 *Examples:
 *  xuitoaW(45, wszResult, 0);   //wszResult == L"45"
 *  xuitoaW(45, wszResult, 4);   //wszResult == L"0045"
 ********************************************************************/
#if defined xuitoaW || defined ALLCONVFUNC
#define xuitoaW_INCLUDED
#undef xuitoaW
wchar_t* xuitoaW(unsigned int number, wchar_t *wstr, int width)
{
  wchar_t wtmp[128]=L"";
  int a=0;
  int b=0;

  if (number == 0)
  {
    wstr[0]='0';
    --width;
    b=1;
  }
  for (wtmp[a]='\0'; number != 0; ++a)
  {
    wtmp[a]=(number % 10) + '0';
    number=number / 10;
  }
  for (; width > a; ++a) wtmp[a]='0';
  for (--a; a >= 0; --a, ++b) wstr[b]=wtmp[a];

  wstr[b]='\0';
  return wstr;
}
#endif

/********************************************************************
 *
 *  xatoi64
 *
 *Converts string to int64.
 *
 *[in]  char *str   -string number
 *
 *Returns: 64-bit integer
 *
 *Examples:
 *  xatoi64("45") == 45;
 *  xatoi64("  -0045:value") == -45;
 ********************************************************************/
#if defined xatoi64 || defined ALLCONVFUNC
#define xatoi64_INCLUDED
#undef xatoi64
__int64 xatoi64(char *str)
{
  __int64 nNumber=0;
  BOOL bMinus=FALSE;

  while (*str == ' ')
    ++str;
  if (*str == '+')
    ++str;
  else if (*str == '-')
  {
    bMinus=TRUE;
    ++str;
  }
  for (; *str != '\0' && *str >= '0' && *str <= '9'; ++str)
    nNumber=(nNumber * 10) + (*str - '0');
  if (bMinus == TRUE)
    nNumber=0 - nNumber;
  return nNumber;
}
#endif

/********************************************************************
 *
 *  xatoi64W
 *
 *Converts unicode string to int64.
 *
 *[in]  wchar_t *wstr   -unicode string number
 *
 *Returns: 64-bit integer
 *
 *Examples:
 *  xatoi64W(L"45") == 45;
 *  xatoi64W(L"  -0045:value") == -45;
 ********************************************************************/
#if defined xatoi64W || defined ALLCONVFUNC
#define xatoi64W_INCLUDED
#undef xatoi64W
__int64 xatoi64W(wchar_t *wstr)
{
  __int64 nNumber=0;
  BOOL bMinus=FALSE;

  while (*wstr == ' ')
    ++wstr;
  if (*wstr == '+')
    ++wstr;
  else if (*wstr == '-')
  {
    bMinus=TRUE;
    ++wstr;
  }
  for (; *wstr != '\0' && *wstr >= '0' && *wstr <= '9'; ++wstr)
    nNumber=(nNumber * 10) + (*wstr - '0');
  if (bMinus == TRUE)
    nNumber=0 - nNumber;
  return nNumber;
}
#endif

/********************************************************************
 *
 *  xitoa64
 *
 *Converts int64 to string.
 *
 *[in]   __int64 number  -64-bit integer
 *[out]  char *str       -string number
 *[in]   int width       -minimum number of characters to the output
 *
 *Returns: a pointer to string
 *
 *Examples:
 *  xi64toa(45, szResult, 0);   //szResult == "45"
 *  xi64toa(-45, szResult, 0);  //szResult == "-45"
 *  xi64toa(45, szResult, 4);   //szResult == "0045"
 ********************************************************************/
#if defined xi64toa || defined ALLCONVFUNC
#define xi64toa_INCLUDED
#undef xi64toa
char* xi64toa(__int64 number, char *str, int width)
{
  char tmp[128]="";
  int a=0;
  int b=0;

  if (number == 0)
  {
    str[0]='0';
    --width;
    b=1;
  }
  else if (number < 0)
  {
    str[0]='-';
    number=0 - number;
    --width;
    b=1;
  }
  for (tmp[a]='\0'; number != 0; ++a)
  {
    tmp[a]=(char)((number % 10) + '0');
    number=number / 10;
  }
  for (; width > a; ++a) tmp[a]='0';
  for (--a; a >= 0; --a, ++b) str[b]=tmp[a];

  str[b]='\0';
  return str;
}
#endif

/********************************************************************
 *
 *  xitoa64W
 *
 *Converts int64 to unicode string.
 *
 *[in]   __int64 number  -64-bit integer
 *[out]  wchar_t *wstr   -unicode string number
 *[in]   int width       -minimum number of characters to the output
 *
 *Returns: a pointer to unicode string
 *
 *Examples:
 *  xi64toaW(45, wszResult, 0);   //wszResult == L"45"
 *  xi64toaW(-45, wszResult, 0);  //wszResult == L"-45"
 *  xi64toaW(45, wszResult, 4);   //wszResult == L"0045"
 ********************************************************************/
#if defined xi64toaW || defined ALLCONVFUNC
#define xi64toaW_INCLUDED
#undef xi64toaW
wchar_t* xi64toaW(__int64 number, wchar_t *wstr, int width)
{
  wchar_t wtmp[128]=L"";
  int a=0;
  int b=0;

  if (number == 0)
  {
    wstr[0]='0';
    --width;
    b=1;
  }
  else if (number < 0)
  {
    wstr[0]='-';
    number=0 - number;
    --width;
    b=1;
  }
  for (wtmp[a]='\0'; number != 0; ++a)
  {
    wtmp[a]=(char)((number % 10) + '0');
    number=number / 10;
  }
  for (; width > a; ++a) wtmp[a]='0';
  for (--a; a >= 0; --a, ++b) wstr[b]=wtmp[a];

  wstr[b]='\0';
  return wstr;
}
#endif

/********************************************************************
 *
 *  hex2dec
 *
 *Converts hex value to decimal.
 *
 *[in]  char *hex   -hex value
 *
 *Returns: integer
 *         -1 wrong hex value
 *
 *Examples:
 *  hex2dec("A1F") == 2591;
 ********************************************************************/
#if defined hex2dec || defined ALLCONVFUNC
#define hex2dec_INCLUDED
#undef hex2dec
int hex2dec(char *hex)
{
  int a;
  int b=0;

  while (1)
  {
    a=*hex++;
    if (a >= '0' && a <= '9') a-='0';
    else if (a >= 'a' && a <= 'f') a-='a'-10;
    else if (a >= 'A' && a <= 'F') a-='A'-10;
    else return -1;

    if (*hex) b=(b + a) * 16;
    else return (b + a);
  }
}
#endif

/********************************************************************
 *
 *  hex2decW
 *
 *Converts unicode hex value to decimal.
 *
 *[in]  wchar_t *whex   -unicode hex value
 *
 *Returns: integer
 *         -1 wrong hex value
 *
 *Examples:
 *  hex2decW(L"A1F") == 2591;
 ********************************************************************/
#if defined hex2decW || defined ALLCONVFUNC
#define hex2decW_INCLUDED
#undef hex2decW
int hex2decW(wchar_t *whex)
{
  int a;
  int b=0;

  while (1)
  {
    a=*whex++;
    if (a >= '0' && a <= '9') a-='0';
    else if (a >= 'a' && a <= 'f') a-='a'-10;
    else if (a >= 'A' && a <= 'F') a-='A'-10;
    else return -1;

    if (*whex) b=(b + a) * 16;
    else return (b + a);
  }
}
#endif

/********************************************************************
 *
 *  dec2hex   [API: wsprintf(szResult, "%02x", 2591)]
 *
 *Converts decimal to hex value.
 *
 *[in]   unsigned int dec   -positive integer
 *[out]  char *hex          -hex value (output)
 *[in]   BOOL lowercase     -if TRUE hexadecimal value in lowercase
 *                           if FALSE in uppercase.
 *[in]   unsigned int width -minimum number of characters to the output
 *
 *Examples:
 *  dec2hex(2591, szResult, FALSE, 2);   //szResult == "A1F"
 *  dec2hex(10, szResult, TRUE, 2);      //szResult == "0a"
 ********************************************************************/
#if defined dec2hex || defined ALLCONVFUNC
#define dec2hex_INCLUDED
#undef dec2hex
void dec2hex(unsigned int dec, char *hex, BOOL lowercase, unsigned int width)
{
  unsigned int a=dec;
  unsigned int b=0;
  unsigned int c=0;
  char d='1';
  if (a == 0) d='0';

  while (a)
  {
    b=a % 16;
    a=a / 16;
    if (b < 10) hex[c++]=b + '0';
    else if (lowercase == TRUE) hex[c++]=b + 'a' - 10;
    else hex[c++]=b + 'A' - 10;
  }
  while (width > c) hex[c++]='0';
  hex[c]='\0';

  if (d == '1')
    for (b=0, --c; b < c; d=hex[b], hex[b++]=hex[c], hex[c--]=d);
}
#endif

/********************************************************************
 *
 *  dec2hexW   [API: wsprintfW(wszResult, L"%02x", 2591)]
 *
 *Converts decimal to unicode hex value.
 *
 *[in]   unsigned int dec   -positive integer
 *[out]  wchar_t *whex      -unicode hex value (output)
 *[in]   BOOL lowercase     -if TRUE hexadecimal value in lowercase
 *                           if FALSE in uppercase.
 *[in]   unsigned int width -minimum number of characters to the output
 *
 *Examples:
 *  dec2hexW(2591, wszResult, FALSE, 2);   //wszResult == L"A1F"
 *  dec2hexW(10, wszResult, TRUE, 2);      //wszResult == L"0a"
 ********************************************************************/
#if defined dec2hexW || defined ALLCONVFUNC
#define dec2hexW_INCLUDED
#undef dec2hexW
void dec2hexW(unsigned int dec, wchar_t *whex, BOOL lowercase, unsigned int width)
{
  unsigned int a=dec;
  unsigned int b=0;
  unsigned int c=0;
  wchar_t d='1';
  if (a == 0) d='0';

  while (a)
  {
    b=a % 16;
    a=a / 16;
    if (b < 10) whex[c++]=b + '0';
    else if (lowercase == TRUE) whex[c++]=b + 'a' - 10;
    else whex[c++]=b + 'A' - 10;
  }
  while (width > c) whex[c++]='0';
  whex[c]='\0';

  if (d == '1')
    for (b=0, --c; b < c; d=whex[b], whex[b++]=whex[c], whex[c--]=d);
}
#endif

/********************************************************************
 *
 *  str2hex
 *
 *Converts string to hex values.
 *
 *[in]   unsigned char *str   -string
 *[out]  char *hex            -hex string
 *[in]   BOOL lowercase       -if TRUE hexadecimal value in lowercase
 *                             if FALSE in uppercase.
 *[in]   unsigned int bytes   -number of bytes in string
 *
 *Note:
 *  str2hex uses dec2hex
 *
 *Examples:
 *  str2hex((unsigned char *)"Some Text", szResult, TRUE, lstrlen("Some Text"));   //szResult == "536f6d652054657874"
 ********************************************************************/
#if defined str2hex || defined ALLCONVFUNCS
#define str2hex_INCLUDED
#undef str2hex
void str2hex(unsigned char *str, char *hex, BOOL lowercase, unsigned int bytes)
{
  char a[16];
  unsigned int b=0;

  for (hex[0]='\0'; b < bytes; ++b)
  {
    //wsprintf(a, "%02x", (unsigned int)str[b]);
    dec2hex((unsigned int)str[b], a, lowercase, 2);
    lstrcat(hex, a);
  }
}
#endif

/********************************************************************
 *
 *  hex2str
 *
 *Converts hex values to string.
 *
 *[in]   char *hex   -hex string
 *[out]  char *str   -string
 *
 *Examples:
 *  hex2str("536f6d652054657874", szResult);   //szResult == "Some Text"
 ********************************************************************/
#if defined hex2str || defined ALLCONVFUNCS
#define hex2str_INCLUDED
#undef hex2str
void hex2str(char *hex, char *str)
{
  char a[4];
  int b;

  while (*hex)
  {
    a[0]=*hex;
    a[1]=*++hex;
    a[2]='\0';

    if (*hex++)
    {
      if ((b=hex2dec(a)) > 0) *str++=b;
      else break;
            }
    else break;
  }
  *str='\0';
}
#endif


/********************************************************************
 *                                                                  *
 *                           Example                                *
 *                                                                  *
 ********************************************************************

#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdio.h>
#include "ConvFunc.h"

//insert functions
#define xatoi
#define xitoa
#include "ConvFunc.h"

void main()
{
  char szResult[MAX_PATH]="43";
  char *pResult;
  int nError;

  nError=xatoi(szResult);
  printf("nError={%d}\n", nError);

  pResult=xitoa(45, szResult, 0);
  printf("szResult={%s}, pResult={%s}\n", szResult, pResult);
}

*/