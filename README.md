# LÖVR VR Jumpstart

**PC VR development with Meta Quest 3S (SteamVR / OpenXR)**

This guide walks you through setting up **LÖVR** for **PC VR development**, running my hello_world VR app.

---

## 🧠 What is LÖVR?

**LÖVR** is a lightweight, open-source 3D & VR framework written in **Lua**, powered by **OpenXR** and **Vulkan**.

* No editor — code-first workflow
* Cross-headset PC VR via OpenXR
* Small, fast, hackable
* Perfect for prototyping, tools, and experimental VR games

Website: [https://lovr.org](https://lovr.org)
Docs: [https://lovr.org/docs](https://lovr.org/docs)

---

## 🎯 Target setup for this guide

* OS: **Windows / Linux**
* Headset: **Meta Quest 3S**
* Mode: **PC VR**
* Runtime: **SteamVR (OpenXR)**
* Language: **Lua (LuaJIT)**

---

## 🧩 Architecture overview (important)

In PC VR mode, the connection looks like this:

```
Quest 3S (display + tracking)
          ↓
      SteamVR
          ↓
      OpenXR runtime
          ↓
        LÖVR
          ↓
        Your game
```

LÖVR talks to **OpenXR**, not directly to the headset.

---

## 1️⃣ Install prerequisites

### 1. Install Steam & SteamVR

1. Install **Steam**
2. Install **SteamVR** from Steam
3. Launch SteamVR once to complete setup

---

### 2. Set SteamVR as OpenXR runtime

In **SteamVR** (no need to have the headset on yet):

* Settings → OpenXR
* Check that your current **OpenXR Runtime is SteamVR**

This is critical.

---

### 3. Connect Quest 3S to PC

I use Steam Link, I haven't tried airlink or data cable.

Once connected:

* Put on headset
* Confirm you see SteamVR Home

---

## 2️⃣ Install LÖVR

1. Download LÖVR from:
   👉 [https://lovr.org/downloads](https://lovr.org/downloads)

2. Extract it somewhere, for example:

```
C:\lovr\
```

3. Add `lovr.exe` to your PATH

Verify installation:

```bash
lovr --version
```

---

## 3️⃣ Run the hello_world project to make sure the setup works

Run it:

```bash
lovr .
```

Put on your headset — you should see floating text in front of you.

---
