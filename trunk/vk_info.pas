(*
    VKontakte plugin for Miranda IM: the free IM client for Microsoft Windows

    Copyright (c) 2009 Andrey Lukyanov

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*)

{-----------------------------------------------------------------------------
 vk_info.pas

 [ Description ]
 Module to receive info about contacts

 [ Known Issues ]
 See the code

 Contributors: LA
-----------------------------------------------------------------------------}
unit vk_info;

interface

uses
  Windows;

  procedure InfoInit();
  procedure InfoDestroy();
  function GetInfoAllProc(): LongWord;
  function GetInfoProc(hContact: lParam): LongWord;

implementation

uses
  m_globaldefs,
  m_api,

  vk_global, // module with global variables and constant used
  vk_common, // module with common functions
  vk_http, // module to connect with the site
  vk_avatars, // module to support avatars
  htmlparse, // module to simplify html parsing
  vk_core, // module with core functions
  vk_popup, // module to support popups  

  StrUtils,
  SysUtils, DateUtils;

var
  vk_hGetInfo: THandle;

// =============================================================================
// procedure to get short information about contact
// -----------------------------------------------------------------------------
procedure vk_GetInfoMinimal(hContact: THandle);
var HTML: String;
   ContactFullName, ContactFirstName, ContactLastName: WideString;
   ContactFN: TFriendName;
   DOB: TDateTime;
   PhoneMobile, PhoneHome, Education: WideString;
   AvatarURL: String;
   BirthYear: Integer;
   StrTemp: WideString;
   Age: Smallint;
   DOBM, DOBD: Byte;
   DOBY: Word;

begin
 HTML := HTTP_NL_Get(Format(vk_url_pda_friend,[DBGetContactSettingDWord(hContact, piShortName, 'ID', 0)]));
 HTML := UTF8Decode(HTML);

 if Trim(HTML) <> '' then
 begin
   if Pos('������������ ��������� ������ ��� �������� � ���������� �����������', HTML) > 0 then // page closed
   begin
     // nothing can be done
   end
   else
   begin
     ContactFullName := TextBetween(HTML,'<h3>', '</h3>');
     ContactFullName := Trim(HTMLDecodeW(ContactFullName));
     ContactFN := FullNameToNameSurnameNick(ContactFullName);
     ContactFirstName := ContactFN.FirstName;
     ContactLastName := ContactFN.LastName;
     ContactFirstName := HTMLDecodeW(ContactFirstName);
     ContactLastName := HTMLDecodeW(ContactLastName);
     DBWriteContactSettingUnicode(hContact, piShortName, 'FirstName', PWideChar(ContactFirstName));
     DBWriteContactSettingUnicode(hContact, piShortName, 'LastName', PWideChar(ContactLastName));

     try
       StrTemp := TextBetween(HTML, '���� ��������: ', '<br/>');
       if Trim(StrTemp) <> '' then
       begin
         if Not TryStrToInt(RightStr(StrTemp, 4), BirthYear) then
           StrTemp := StrTemp + ' 1900';
         DOB := RusDateToDateTime(StrTemp, true);
         DBWriteContactSettingByte(hContact, piShortName, 'BirthDay', StrToInt(FormatDateTime('dd', DOB)));
         DBWriteContactSettingByte(hContact, piShortName, 'BirthMonth', StrToInt(FormatDateTime('mm', DOB)));
         if StrToInt(FormatDateTime('yyyy', DOB)) <> 1900 then
           DBWriteContactSettingWord(hContact, piShortName, 'BirthYear', StrToInt(FormatDateTime('yyyy', DOB)));
       end;
     except
     end;
     // calculating age
     DBDeleteContactSetting(hContact, piShortName, 'Age');
     DOBY := DBGetContactSettingWord(hContact, piShortName, 'BirthYear', 0);
     DOBM := DBGetContactSettingByte(hContact, piShortName, 'BirthMonth', 0);
     DOBD := DBGetContactSettingByte(hContact, piShortName, 'BirthDay', 0);
     if (DOBY > 0) and (DOBY < 10000) and
        (DOBM > 0) and (DOBM <= 12) and
        (DOBD > 0) and (DOBD <= 31) then
     begin
       Age := CurrentYear - DOBY;
       if (MonthOf(Now) < DOBM) or
          ((MonthOf(Now) = DOBM) and (DayOf(Now) < DOBD)) then
            Age := Age - 1;
       if Age > 0 then
         DBWriteContactSettingWord(hContact, piShortName, 'Age', Age);
     end;

     PhoneMobile := Trim(TextBetween(TextBetween(HTML, '���. ���.: ', '<br/>'),'>','<'));
     PhoneMobile := HTMLDecodeW(PhoneMobile);
     if PhoneMobile <> '' Then
       DBWriteContactSettingUnicode(hContact, 'UserInfo', 'MyPhone0', PWideChar(PhoneMobile));

     PhoneHome := Trim(TextBetween(TextBetween(HTML, '���. ���.: ', '<br/>'),'>','<'));
     PhoneHome := HTMLDecodeW(PhoneHome);
     if PhoneHome <> '' Then
       DBWriteContactSettingUnicode(hContact, 'UserInfo', 'MyPhone1', PWideChar(PhoneHome));

     Education := Trim(TextBetween(HTML, '���: ', '<br/>'));
     Education := HTMLDecodeW(Education);
     if Education <> '' Then
     Begin
       DBWriteContactSettingUnicode(hContact, piShortName, 'Affiliation0', TranslateW(usr_dtl_education));
       DBWriteContactSettingUnicode(hContact, piShortName, 'Affiliation0Text', PWideChar(Education));
     End;

     // if update of avatar is required
     if DBGetContactSettingByte(0, piShortName, opt_UserAvatarsUpdateWhenGetInfo, 0) = 1 then
     begin
       // <img class="pphoto" align="left" alt="����" src="http://cs1425.vkontakte.ru/u1234567/c_44e12345.jpg"/>
       AvatarURL := TextBetweenInc(HTML, 'pphoto', '/>');
       AvatarURL := TextBetween(AvatarURL, 'src="', '"');
       AvatarURL := Trim(AvatarURL);
       if AvatarURL <> '' then
         vk_AvatarGetAndSave(IntToStr(DBGetContactSettingDWord(hContact, piShortName, 'ID', 0)), AvatarURL); // update avatar for a contact
     end;
   end;
 end;

 // inform miranda that all data is received
 ProtoBroadcastAck(piShortName,
   hContact,
   ACKTYPE_GETINFO,
   ACKRESULT_SUCCESS,
   1,
   0);
end;
// =============================================================================
// procedure to get full information about contact
// -----------------------------------------------------------------------------
procedure vk_GetInfoFull(hContact: THandle);
var HTML: String;
   StrTemp, BasicInfo, ContactInfo, EduInfo, CareerInfo, PlaceInfo: WideString;
   ContactFN: TFriendName;
   DOB: TDateTime;
   BirthYear: Integer;
   Age: Smallint;
   DOBM, DOBD: Byte;
   DOBY: Word;
      
begin
 HTML := HTTP_NL_Get(Format(vk_url_friend,[DBGetContactSettingDWord(hContact, piShortName, 'ID', 0)]));

 if Trim(HTML) = '' then
 begin
   // inform miranda that data retrieving is finished
   ProtoBroadcastAck(piShortName,
       hContact,
       ACKTYPE_GETINFO,
       ACKRESULT_SUCCESS, // check this result
       1,
       0);
   Exit;
 end;

 if Pos('<title>� �������� | ����� �����</title>', HTML) > 0 then // page is closed
 begin
   BasicInfo := TextBetweenInc(HTML,'<div class="info"','</li>');
   if Trim(BasicInfo) <> '' then
   begin
     // name
     StrTemp := HTMLRemoveTags(Trim(TextBetween(BasicInfo, '<dt>���:', '<dt>')));
     if StrTemp = '' Then
        StrTemp := HTMLRemoveTags(Trim(TextBetween(BasicInfo, '<dt>���:', '</dd>')));
     StrTemp := HTMLDecodeW(Trim(StrTemp));
     ContactFN := FullNameToNameSurnameNick(StrTemp);
     if Trim(ContactFN.FirstName) <> '' Then
       DBWriteContactSettingUnicode(hContact, piShortName, 'FirstName', PWideChar(ContactFN.FirstName));
     if Trim(ContactFN.LastName) <> '' Then
       DBWriteContactSettingUnicode(hContact, piShortName, 'LastName', PWideChar(ContactFN.LastName));

     // higher education
     StrTemp := TextBetween(BasicInfo, '<dt>������:', '<dt>');
     StrTemp := Trim(HTMLRemoveTags(HTMLDecodeW(StrTemp)));
     if StrTemp <> '' Then
     Begin
       DBWriteContactSettingUnicode(hContact, piShortName, 'Affiliation0', TranslateW(usr_dtl_education));
       DBWriteContactSettingUnicode(hContact, piShortName, 'Affiliation0Text', PWideChar(StrTemp));
     End;

     if Pos('&nbsp', BasicInfo) > 0 then
        StrTemp := TextBetween(BasicInfo, '<dt>���������:', '&nbsp')
     else
        StrTemp := TextBetween(BasicInfo, '<dt>���������:', '</dd>');
     StrTemp := Trim(HTMLRemoveTags(HTMLDecodeW(StrTemp)));
     if StrTemp <> '' Then
     Begin
       DBWriteContactSettingUnicode(hContact, piShortName, 'Affiliation1', TranslateW(usr_dtl_faculty));
       DBWriteContactSettingUnicode(hContact, piShortName, 'Affiliation1Text', PWideChar(StrTemp));
     End;
   end;
   // inform miranda that data retrieving is finished
   ProtoBroadcastAck(piShortName,
       hContact,
       ACKTYPE_GETINFO,
       ACKRESULT_SUCCESS, // check this result
       1,
       0);
 end
 else // page is opened
 begin
   // inform miranda that 1/4 data is received
   ProtoBroadcastAck(piShortName,
     hContact,
     ACKTYPE_GETINFO,
     ACKRESULT_SUCCESS,
     4,    // <-- count of replies to be received
     0);   // <-- current reply, starts from 0

   BasicInfo := TextBetween(HTML,'<div id="rightColumn">', 'div id="wall"');

   if Trim(BasicInfo) <> '' then
   begin

     // name
     StrTemp := TextBetween(BasicInfo,'<div class="profileName">', '</div>');
     if StrTemp <> '' then
     begin
       StrTemp := TextBetween(StrTemp,'<h2>', '</h2>');
       StrTemp := HTMLDecodeW(StrTemp);
       StrTemp := Trim(StrTemp);
       ContactFN := FullNameToNameSurnameNick(StrTemp);
       if Trim(ContactFN.FirstName) <> '' Then
         DBWriteContactSettingUnicode(hContact, piShortName, 'FirstName', PWideChar(ContactFN.FirstName));
       if Trim(ContactFN.LastName) <> '' Then
         DBWriteContactSettingUnicode(hContact, piShortName, 'LastName', PWideChar(ContactFN.LastName));
     end;

     // gender
     StrTemp := TextBetween(BasicInfo,'<td class="label">���:</td>', '</td>');
     if StrTemp <> '' then
     begin
       StrTemp := TextBetween(StrTemp,'''>', '</a>');
       StrTemp := Trim(StrTemp);
       if StrTemp = '�������' then
         DBWriteContactSettingByte(hContact, piShortName, 'Gender', 77);
       if StrTemp = '�������' then
         DBWriteContactSettingByte(hContact, piShortName, 'Gender', 70);
     end;

     // marital status
     {StrTemp := TextBetween(BasicInfo,'<td class="label">�������� ���������:</td>', '</td>');
     StrTemp := TextBetween(StrTemp,'''>', '</a>');}

     // birthday
     StrTemp := TextBetween(BasicInfo,'<td class="label">���� ��������:</td>', '</td>');
     if StrTemp <> '' then
     begin
       StrTemp := Trim(TextBetween(StrTemp,'<div class="dataWrap">', '</div>'));
       StrTemp := HTMLRemoveTags(StrTemp);
       try
         if Trim(StrTemp) <> '' then
         begin
           if Not TryStrToInt(RightStr(StrTemp, 4), BirthYear) then
             StrTemp := StrTemp + ' 1900';
           if Length(StrTemp) = 4 then // only year is given
             DBWriteContactSettingWord(hContact, piShortName, 'BirthYear', StrToInt(StrTemp))
           else
           begin
             DOB := RusDateToDateTime(StrTemp, true);
             DBWriteContactSettingByte(hContact, piShortName, 'BirthDay', StrToInt(FormatDateTime('dd', DOB)));
             DBWriteContactSettingByte(hContact, piShortName, 'BirthMonth', StrToInt(FormatDateTime('mm', DOB)));
             if StrToInt(FormatDateTime('yyyy', DOB)) <> 1900 then
               DBWriteContactSettingWord(hContact, piShortName, 'BirthYear', StrToInt(FormatDateTime('yyyy', DOB)));
           end;
         end;
       except
       end;
     end;
     // calculating age
     DBDeleteContactSetting(hContact, piShortName, 'Age');
     DOBY := DBGetContactSettingWord(hContact, piShortName, 'BirthYear', 0);
     DOBM := DBGetContactSettingByte(hContact, piShortName, 'BirthMonth', 0);
     DOBD := DBGetContactSettingByte(hContact, piShortName, 'BirthDay', 0);
     if (DOBY > 0) and (DOBY < 10000) and
        (DOBM > 0) and (DOBM <= 12) and
        (DOBD > 0) and (DOBD <= 31) then
     begin
       Age := CurrentYear - DOBY;
       if (MonthOf(Now) < DOBM) or
          ((MonthOf(Now) = DOBM) and (DayOf(Now) < DOBD)) then
            Age := Age - 1;
       if Age > 0 then
         DBWriteContactSettingWord(hContact, piShortName, 'Age', Age);
     end;


     // origin city
     StrTemp := TextBetween(BasicInfo,'<td class="label">������ �����:</td>', '</td>');
     if StrTemp <> '' then
     begin
       StrTemp := TextBetween(StrTemp,'''>', '</a>');
       StrTemp := Trim(StrTemp);
       StrTemp := HTMLDecodeW(StrTemp);
       if StrTemp <> '' Then
         DBWriteContactSettingUnicode(hContact, piShortName, 'OriginCity', PWideChar(StrTemp));
     end;

     // political
     {StrTemp := TextBetween(BasicInfo,'<td class="label">�����. �������:</td>', '</td>');
     StrTemp := TextBetween(StrTemp,'''>', '</a>');}

     // religion
     {StrTemp := TextBetween(BasicInfo,'<td class="label">�����. �������:</td>', '</td>');
     StrTemp := TextBetween(StrTemp,'''>', '</a>');}

   end;

   // inform miranda that 2/4 data is received
   ProtoBroadcastAck(piShortName,
     hContact,
     ACKTYPE_GETINFO,
     ACKRESULT_SUCCESS,
     4,
     1);

   ContactInfo := TextBetween(HTML,'<h4>���������� ����������', 'div id="wall"');

   if Trim(ContactInfo) <> '' then
   begin
     // mobile phone
     StrTemp := TextBetween(ContactInfo,'<td class="label">���. �������:</td>', '</td>');
     if StrTemp <> '' then
     begin
       StrTemp := Trim(TextBetween(StrTemp,'<div class="dataWrap">', '</div>'));
       StrTemp := HTMLDecodeW(StrTemp);
       if (Trim(StrTemp) <> '') and (Pos('���������� ������', StrTemp)=0) Then
         DBWriteContactSettingUnicode(hContact, 'UserInfo', 'MyPhone0', PWideChar(StrTemp));
     end;

     // home phone
     StrTemp := TextBetween(ContactInfo,'<td class="label">���. �������:</td>', '</td>');
     if StrTemp <> '' then
     begin
       StrTemp := Trim(TextBetween(StrTemp,'<div class="dataWrap">', '</div>'));
       StrTemp := HTMLDecodeW(StrTemp);
       if (Trim(StrTemp) <> '') and (Pos('���������� ������', StrTemp)=0) Then
         DBWriteContactSettingUnicode(hContact, 'UserInfo', 'MyPhone1', PWideChar(StrTemp));
     end;

     // webpage
     // depending on the setting we put here either contact's page (read from
     // contact's page or just vkontakte's page url
     if DBGetContactSettingByte(0, piShortName, opt_UserVKontakteURL, 0) = 0 then
     begin
       StrTemp := TextBetween(ContactInfo,'<td class="label">���-����:</td>', '</td>');
       StrTemp := Trim(TextBetween(StrTemp,'''>', '</a>'));
     end
     else
       StrTemp := Format(vk_url_friend,[DBGetContactSettingDWord(hContact, piShortName, 'ID', 0)]);
     if Trim(StrTemp) <> '' Then
       DBWriteContactSettingString(hContact, piShortName, 'Homepage', PChar(String(StrTemp)));

     // business
     StrTemp := TextBetween(ContactInfo,'<td class="label">������������:</td>', '</td>');
     if StrTemp <> '' then
     begin
       StrTemp := HTMLRemoveTags(Trim(TextBetween(StrTemp,'<div class="dataWrap">', '</div>')));
       StrTemp := Trim(HTMLDecodeW(StrTemp));
       if StrTemp <> '' Then
       Begin
         DBWriteContactSettingUnicode(hContact, piShortName, 'Interest0Cat', TranslateW(usr_dtl_occupation));
         DBWriteContactSettingUnicode(hContact, piShortName, 'Interest0Text', PWideChar(StrTemp));
       End;
     end;

     // hobby
     StrTemp := TextBetween(ContactInfo,'<td class="label">��������:</td>', '</td>');
     if StrTemp <> '' then
     begin
       StrTemp := HTMLRemoveTags(Trim(TextBetween(StrTemp,'<div class="dataWrap">', '</div>')));
       StrTemp := Trim(HTMLDecodeW(StrTemp));
       if StrTemp <> '' Then
       Begin
         DBWriteContactSettingUnicode(hContact, piShortName, 'Interest1Cat', TranslateW(usr_dtl_hobby));
         DBWriteContactSettingUnicode(hContact, piShortName, 'Interest1Text', PWideChar(StrTemp));
       End;
     end;

     // music
     StrTemp := TextBetween(ContactInfo,'<td class="label">������� ������:</td>', '</td>');
     if StrTemp <> '' then
     begin
       StrTemp := HTMLRemoveTags(Trim(TextBetween(StrTemp,'<div class="dataWrap">', '</div>')));
       StrTemp := Trim(HTMLDecodeW(StrTemp));
       if StrTemp <> '' Then
       Begin
         DBWriteContactSettingUnicode(hContact, piShortName, 'Interest2Cat', TranslateW(usr_dtl_music));
         DBWriteContactSettingUnicode(hContact, piShortName, 'Interest2Text', PWideChar(StrTemp));
       End;
     end;

     // movies
     StrTemp := TextBetween(ContactInfo,'<td class="label">������� ������:</td>', '</td>');
     if StrTemp <> '' then
     begin
       StrTemp := HTMLRemoveTags(Trim(TextBetween(StrTemp,'<div class="dataWrap">', '</div>')));
       StrTemp := Trim(HTMLDecodeW(StrTemp));
       if StrTemp <> '' Then
       Begin
         DBWriteContactSettingUnicode(hContact, piShortName, 'Interest3Cat', TranslateW(usr_dtl_movies));
         DBWriteContactSettingUnicode(hContact, piShortName, 'Interest3Text', PWideChar(StrTemp));
       End;
     end;

     // tv-show
     StrTemp := TextBetween(ContactInfo,'<td class="label">������� �������:</td>', '</td>');
     if StrTemp <> '' then
     begin
       StrTemp := HTMLRemoveTags(Trim(TextBetween(StrTemp,'<div class="dataWrap">', '</div>')));
       StrTemp := Trim(HTMLDecodeW(StrTemp));
       if StrTemp <> '' Then
       Begin
         DBWriteContactSettingUnicode(hContact, piShortName, 'Interest4Cat', TranslateW(usr_dtl_shows));
         DBWriteContactSettingUnicode(hContact, piShortName, 'Interest4Text', PWideChar(StrTemp));
       End;
     end;

     // books
     StrTemp := TextBetween(ContactInfo,'<td class="label">������� �����:</td>', '</td>');
     if StrTemp <> '' then
     begin
       StrTemp := HTMLRemoveTags(Trim(TextBetween(StrTemp,'<div class="dataWrap">', '</div>')));
       StrTemp := Trim(HTMLDecodeW(StrTemp));
       if StrTemp <> '' Then
       Begin
         DBWriteContactSettingUnicode(hContact, piShortName, 'Interest5Cat', TranslateW(usr_dtl_books));
         DBWriteContactSettingUnicode(hContact, piShortName, 'Interest5Text', PWideChar(StrTemp));
       End;
     end;

     // games
     StrTemp := TextBetween(ContactInfo,'<td class="label">������� ����:</td>', '</td>');
     if StrTemp <> '' then
     begin
       StrTemp := HTMLRemoveTags(Trim(TextBetween(StrTemp,'<div class="dataWrap">', '</div>')));
       StrTemp := Trim(HTMLDecodeW(StrTemp));
       if StrTemp <> '' Then
       Begin
         DBWriteContactSettingUnicode(hContact, piShortName, 'Interest6Cat', TranslateW(usr_dtl_games));
         DBWriteContactSettingUnicode(hContact, piShortName, 'Interest6Text', PWideChar(StrTemp));
       End;
     end;

     // quotes
     StrTemp := TextBetween(ContactInfo,'<td class="label">������� ������:</td>', '</td>');
     if StrTemp <> '' then
     begin
       StrTemp := HTMLRemoveTags(Trim(TextBetween(StrTemp,'<div class="dataWrap">', '</div>')));
       StrTemp := Trim(HTMLDecodeW(StrTemp));
       if StrTemp <> '' Then
       Begin
         DBWriteContactSettingUnicode(hContact, piShortName, 'Interest7Cat', TranslateW(usr_dtl_quotes));
         DBWriteContactSettingUnicode(hContact, piShortName, 'Interest7Text', PWideChar(StrTemp));
       End;
     end;

     // ICQ
     DBDeleteContactSetting(hContact, piShortName, 'About');
     StrTemp := TextBetween(ContactInfo,'<td class="label">ICQ:</td>', '</td>');
     if StrTemp <> '' then
     begin
       StrTemp := Trim(TextBetween(StrTemp,'<div class="dataWrap">', '</div>'));
       StrTemp := Trim(HTMLRemoveTags(StrTemp));
       StrTemp := HTMLDecodeW(StrTemp);
       if Trim(StrTemp) <> '' Then
       begin
         StrTemp := 'ICQ ' + StrTemp + #13#10;
         DBWriteContactSettingUnicode(hContact, piShortName, 'About', PWideChar(StrTemp));
       end;
     end;

     // about
     StrTemp := TextBetween(ContactInfo,'<td class="label">� ����:</td>', '</td>');
     if StrTemp <> '' then
     begin
       StrTemp := Trim(TextBetween(StrTemp,'<div class="dataWrap">', '</div>'));
       StrTemp := StringReplace(StrTemp, '<br>', Chr(13) + Chr(10), [rfReplaceAll]);
       StrTemp := Trim(HTMLDecodeW(StrTemp));
       if StrTemp <> '' then
       begin
         StrTemp := DBReadUnicode(hContact, piShortName, 'About', '') + StrTemp;
         DBWriteContactSettingUnicode(hContact, piShortName, 'About', PWideChar(StrTemp));
       end;
     end;
   end;

   // inform miranda that 3/4 data is received
   ProtoBroadcastAck(piShortName,
     hContact,
     ACKTYPE_GETINFO,
     ACKRESULT_SUCCESS,
     4,
     2);

   EduInfo := TextBetween(HTML, '<h2>�����������</h2>', 'div id="wall"');

   if Trim(EduInfo) <> '' then
   begin
     // higher education
     StrTemp := TextBetween(EduInfo,'<td class="label">���:</td>', '</td>');
     if StrTemp <> '' then
     begin
       StrTemp := HTMLRemoveTags(Trim(TextBetween(StrTemp,'<div class="dataWrap">', '</div>')));
       StrTemp := Trim(HTMLDecodeW(StrTemp));
       if StrTemp <> '' Then
       Begin
         DBWriteContactSettingUnicode(hContact, piShortName, 'Affiliation0', TranslateW(usr_dtl_education));
         DBWriteContactSettingUnicode(hContact, piShortName, 'Affiliation0Text', PWideChar(StrTemp));
       End;
     end;

     StrTemp := TextBetween(EduInfo,'<td class="label">���������:</td>', '</td>');
     if StrTemp <> '' then
     begin
       StrTemp := HTMLRemoveTags(Trim(TextBetween(StrTemp,'<div class="dataWrap">', '</div>')));
       StrTemp := Trim(HTMLDecodeW(StrTemp));
       if StrTemp <> '' Then
       Begin
         DBWriteContactSettingUnicode(hContact, piShortName, 'Affiliation1', TranslateW(usr_dtl_faculty));
         DBWriteContactSettingUnicode(hContact, piShortName, 'Affiliation1Text', PWideChar(StrTemp));
       End;
     end;

     StrTemp := TextBetween(EduInfo,'<td class="label">�������:</td>', '</td>');
     if StrTemp <> '' then
     begin
       StrTemp := HTMLRemoveTags(Trim(TextBetween(StrTemp,'<div class="dataWrap">', '</div>')));
       StrTemp := Trim(HTMLDecodeW(StrTemp));
       if StrTemp <> '' Then
       Begin
         DBWriteContactSettingUnicode(hContact, piShortName, 'Affiliation2', TranslateW(usr_dtl_department));
         DBWriteContactSettingUnicode(hContact, piShortName, 'Affiliation2Text', PWideChar(StrTemp));
       End;
     end;

     // college
     StrTemp := TextBetween(EduInfo,'<td class="label">�������:</td>', '</td>');
     if StrTemp <> '' then
     begin
       StrTemp := Trim(TextBetween(StrTemp,'<div class="dataWrap">', '</div>'));
       StrTemp := HTMLRemoveTags(StrTemp);
       StrTemp := Trim(HTMLDecodeW(StrTemp));
       if StrTemp <> '' Then
       Begin
         DBWriteContactSettingUnicode(hContact, piShortName, 'Affiliation3', TranslateW(usr_dtl_education));
         DBWriteContactSettingUnicode(hContact, piShortName, 'Affiliation3Text', PWideChar(StrTemp));
       End;
     end;

     // school
     StrTemp := TextBetween(EduInfo,'<td class="label">�����:</td>', '</td>');
     if StrTemp <> '' then
     begin
       StrTemp := Trim(TextBetween(StrTemp,'<div class="dataWrap">', '</div>'));
       StrTemp := HTMLRemoveTags(StrTemp);
       StrTemp := Trim(HTMLDecodeW(StrTemp));
       if StrTemp <> '' Then
       Begin
         DBWriteContactSettingUnicode(hContact, piShortName, 'Affiliation4', TranslateW(usr_dtl_school));
         DBWriteContactSettingUnicode(hContact, piShortName, 'Affiliation4Text', PWideChar(StrTemp));
       End;
     end;
   end;

   PlaceInfo := TextBetween(HTML,'div id="places"', 'div id="wall"');

   if Trim(PlaceInfo) <> '' then
   begin
     // address
     StrTemp := TextBetween(PlaceInfo,'<td class="label">�����:</td>', '</td>');
     if StrTemp <> '' then
     begin
       StrTemp := HTMLRemoveTags(Trim(TextBetween(StrTemp,'<div class="dataWrap">', '</div>')));
       StrTemp := Trim(HTMLDecodeW(StrTemp));
       if StrTemp <> '' Then
         DBWriteContactSettingUnicode(hContact, piShortName, 'Street', PWideChar(StrTemp));
     end;
   end;

   CareerInfo := TextBetween(HTML,'div id="career"', 'div id="wall"');

   if Trim(CareerInfo) <> '' then
   begin
     // company
     StrTemp := TextBetween(CareerInfo,'<td class="label">����� ������:</td>', '</td>');
     if StrTemp <> '' then
     begin
       StrTemp := HTMLRemoveTags(Trim(TextBetween(StrTemp,'<div class="dataWrap">', '</div>')));
       StrTemp := Trim(HTMLDecodeW(StrTemp));
       if StrTemp <> '' Then
         DBWriteContactSettingUnicode(hContact, piShortName, 'Company', PWideChar(StrTemp));
     end;
   end;

   // if update of avatar is required
   if DBGetContactSettingByte(0, piShortName, opt_UserAvatarsUpdateWhenGetInfo, 0) = 1 then
   begin
     StrTemp := TextBetween(HTML,'div id="leftColumn"', '</div>');
     StrTemp := TextBetween(StrTemp,'SRC=', ' ');
     if Trim(StrTemp)<>'' then
       try
         vk_AvatarGetAndSave(IntToStr(DBGetContactSettingDWord(hContact, piShortName, 'ID', 0)), StrTemp); // update avatar for a contact
       except
       end;
   end;

   // inform miranda that 4/4 (all!) data is received
   ProtoBroadcastAck(piShortName,
     hContact,
     ACKTYPE_GETINFO,
     ACKRESULT_SUCCESS,
     4,
     3);
 end;
end;

// =============================================================================
// function to react on miranda's request to get details about contact
// -----------------------------------------------------------------------------
function GetInfo(wParam: wParam; lParam: lParam): Integer; cdecl;
var res: LongWord;
    hContact: THandle;
begin
  hContact := PCCSDATA(lParam).hContact;
  CloseHandle(BeginThread(nil, 0, @GetInfoProc, Pointer(hContact), 0, res));

  Result := 0;
end;

// =============================================================================
// function to initiate get info support
// -----------------------------------------------------------------------------
procedure InfoInit();
begin
  vk_hGetInfo := CreateProtoServiceFunction(piShortName, PSS_GETINFO, GetInfo);
end;

// =============================================================================
// function to destroy get info support
// -----------------------------------------------------------------------------
procedure InfoDestroy();
begin
  pluginLink^.DestroyServiceFunction(vk_hGetInfo);
end;


// =============================================================================
// get info function - run in a separate thread
// -----------------------------------------------------------------------------
function GetInfoProc(hContact: lParam): LongWord;
begin
  Netlib_Log(vk_hNetlibUser, PChar('(GetInfoProc) Thread started...'));

  if (vk_Status = ID_STATUS_INVISIBLE) Then
    if MessageBox(0, Translate(qst_read_info), Translate(piShortName), MB_YESNO + MB_ICONQUESTION) = IDYES then
      vk_SetStatus(ID_STATUS_ONLINE);

  if (vk_Status = ID_STATUS_ONLINE) Then
  begin
    if DBGetContactSettingByte(0, piShortName, opt_UserGetMinInfo, 1) = 1 then
      vk_GetInfoMinimal(hContact)
    else
      vk_GetInfoFull(hContact);
  end
  else
  ProtoBroadcastAck(piShortName,
    hContact,
    ACKTYPE_GETINFO,
    ACKRESULT_SUCCESS,
    1,
    0);

  Result := 0;

  Netlib_Log(vk_hNetlibUser, PChar('(GetInfoProc) ... thread finished'));
end;

// =============================================================================
// get info for all contacts function - run in a separate thread
// -----------------------------------------------------------------------------
function GetInfoAllProc(): LongWord;
var hContact: THandle;
    hContactID: String;
begin
  Netlib_Log(vk_hNetlibUser, PChar('(GetInfoAllProc) Thread started...'));

  if (vk_Status = ID_STATUS_INVISIBLE) Then
    if MessageBox(0, Translate(qst_read_info), Translate(piShortName), MB_YESNO + MB_ICONQUESTION) = IDYES then
      vk_SetStatus(ID_STATUS_ONLINE);

  if (vk_Status = ID_STATUS_ONLINE) Then
  begin
    hContact := pluginLink^.CallService(MS_DB_CONTACT_FINDFIRST, 0, 0);
	  while hContact <> 0 do
    begin
      if pluginLink^.CallService(MS_PROTO_ISPROTOONCONTACT, hContact, windows.lParam(PAnsiChar(piShortName))) <> 0 Then
      begin
        hContactID := IntToStr(DBGetContactSettingDWord(hContact, piShortName, 'ID', 0));
        Netlib_Log(vk_hNetlibUser, PChar('(GetInfoAllProc) Updating of details of contact ID ' + hContactID + ' ...'));
        if DBGetContactSettingByte(0, piShortName, opt_UserGetMinInfo, 1) = 1 then
          vk_GetInfoMinimal(hContact)
        else
          vk_GetInfoFull(hContact);
        Netlib_Log(vk_hNetlibUser, PChar('(GetInfoAllProc) ... updating of details of contact ID ' + hContactID + ' finished'));
      end;
      hContact := pluginLink^.CallService(MS_DB_CONTACT_FINDNEXT, hContact, 0);
	  end;
    ShowPopupMsg(0, conf_info_update_completed, 1);
  end;
  Result := 0;

  Netlib_Log(vk_hNetlibUser, PChar('(GetInfoAllProc) ... thread finished'));
end;


begin
end.
