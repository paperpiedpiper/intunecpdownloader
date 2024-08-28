# Intune/Company Portal package retriever

Once you've uploaded your .intunewin package to Intune as a Win32 app, the package is (not at all easily) retrievable

### There are a couple of solutions to this:
---
#### 1) The unelegant, but quick one

Change permissions of the following folder (through Security GUI or icacls)
> %ProgramFiles(x86)%\Microsoft Intune Management Extension\Content\Staging

This folder is used by the Intune Management Extension to unpack the .intunewin contents, whenever a normal Company Portal installation happens on a client computer

- Remove delete permissions for everyone, but yourself (especially SYSTEM)
  * See this for details: https://www.youtube.com/watch?v=8EHJVu03lwg
 
This will make it so that the machine keeps all Intune sources it uses for installations

#### 2) The fun, but more tedious one
Based on the IME agent's run log
    ![image](https://github.com/user-attachments/assets/0926f404-6ece-40c0-b8e0-4babf4edffc4)
- One step of preparation is necessary:
  > %ProgramFiles(x86)%\Microsoft Intune Management Extension\Microsoft.Management.Services.IntuneWindowsAgent.exe.config
  * Modify the switch value from 'Information' to 'Verbose' and restart machine (or just the IME agent and service) -- this will make the logs verbose and will share important data, for the script to read
    ![image](https://github.com/user-attachments/assets/b8cf2f94-1d6b-4812-b4fd-83f7f13d1020)


- Download this repo's contents
- Run the .ps1 using Admin elevation
  ![Screenshot 2024-08-29 011857](https://github.com/user-attachments/assets/13ef7e67-a8d6-4558-bd3a-db656df2c843)
![image](https://github.com/user-attachments/assets/aadcc9e4-9189-4685-a4de-97edc1e3ef79)

  * But make sure you enter the name of the app, same as the label Name chose on Intune
    ![image](https://github.com/user-attachments/assets/bf4724b9-b3c0-43d6-8128-9db744967d73)
![Screenshot 2024-08-29 012025](https://github.com/user-attachments/assets/490879f5-8fbe-4f97-b286-144cd6665930)
![Screenshot 2024-08-29 012039](https://github.com/user-attachments/assets/e760b628-efe0-4064-bb77-768dc429f1a9)

---

##### Based on an old script (deprecated by Intune updates) that was written by the Microsoft MDM MVP himself, Oliver Kieselbach (who also wrote IntuneWinAppUtilDecoder)
https://oliverkieselbach.com/2019/01/03/how-to-decode-intune-win32-app-packages/
