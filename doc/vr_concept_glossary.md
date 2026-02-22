# VR / 360 / 180 Glossary for Game Developers

A quick reference guide covering common terminology used in VR game development, immersive media, and spatial computing.

---

## 📐 Display & Projection Formats

**Equirectangular (ERP)**
The most common projection format for 360° content. Maps a full spherical view onto a flat 2:1 rectangular image or video. Think of it like unrolling a globe into a flat map — familiar distortion at the poles is the trade-off.

**180° / 180 VR**
A half-sphere format (front-facing only) commonly used for VR video and stereoscopic content. Less processing overhead than full 360°, and easier to capture with dual-lens cameras.

**Cubemap / Cube Projection**
Projects the spherical environment onto 6 faces of a cube. Often used internally by game engines (Unity, Unreal) for skyboxes and environment reflections. More efficient than equirectangular for real-time rendering.

**EAC (Equi-Angular Cubemap)**
A variant of the cubemap format developed by Google/YouTube that distributes pixels more evenly across cube faces, reducing quality loss at the edges and corners.

**Monoscopic**
A single-image 360° or 180° view — no depth perception. Same image is sent to both eyes. Cheaper to produce but lacks the sense of depth.

**Stereoscopic (Stereo 3D)**
Dual-image format with slightly offset perspectives for the left and right eye, creating the illusion of depth. Stored as **Top/Bottom (Over/Under)** or **Side-by-Side (SbS)** layouts.

**IPD (Interpupillary Distance)**
The distance between a person's pupils (~63mm average). VR headsets adjust lens spacing to match the user's IPD for proper stereo alignment and comfort.

---

## 🕶️ Headset & Optics

**HMD (Head-Mounted Display)**
The headset itself — the device worn on the head that delivers the visual (and often audio) experience. Examples: Meta Quest, Valve Index, Apple Vision Pro, PlayStation VR2.

**FOV (Field of View)**
The extent of the visible world at any given moment, measured in degrees. Human FOV is ~200°; most HMDs offer ~90–120°. A wider FOV increases immersion but is harder to render.

**Fresnel Lens**
A lightweight, flat lens with concentric ridges used in most modern VR headsets to bend light efficiently. Trade-off: can cause "god rays" or glare artifacts.

**Pancake Lens**
A newer, thinner lens design used in headsets like the Meta Quest 3. Sharper image with less glare than Fresnel, but lower light efficiency.

**PPD (Pixels Per Degree)**
Measure of visual sharpness in VR — how many pixels cover one degree of your field of view. Higher PPD = less visible screen-door effect.

**Screen-Door Effect (SDE)**
The visible grid between pixels in a display, making it look like you're viewing through a screen door. Less common in modern high-res headsets.

**Varifocal / Eye Tracking**
Technology that dynamically adjusts lens focus based on where the user is looking. Enables foveated rendering and more natural depth perception.

---

## 🔄 Tracking & Movement

**6DoF (Six Degrees of Freedom)**
Full spatial tracking — position (X, Y, Z translation) AND rotation (pitch, yaw, roll). You can physically move around in space. The standard for modern VR gaming.

**3DoF (Three Degrees of Freedom)**
Rotation only (pitch, yaw, roll) — no positional tracking. Your head turns but the system doesn't know if you've moved. Common in older or budget headsets and 360° video viewers.

**Room-Scale**
A play area setup that lets users physically walk around within a defined space (typically 2m×2m or larger), tracked by the headset. Guardian/boundary systems define the safe zone.

**Stationary / Seated Mode**
VR experience designed to be used while seated or standing in one spot, without requiring room-scale movement.

**Inside-Out Tracking**
Tracking achieved using cameras built into the headset itself to map the environment. No external base stations needed. Used by Meta Quest, PlayStation VR2.

**Outside-In Tracking**
Tracking using external base stations or cameras placed in the room (e.g., Valve Index with SteamVR Lighthouse base stations). Generally more precise.

**Lighthouse / Base Station**
External tracking hardware used by SteamVR-compatible devices. Emits laser sweeps that controllers and headsets detect to determine their position.

**Chaperone / Guardian**
The virtual boundary system that warns users when they're approaching the edge of their play space. Shows a virtual grid wall when you get close.

---

## 🎮 Interaction & Input

**Motion Controllers**
Handheld tracked controllers with buttons, triggers, and thumbsticks. The primary input method for most VR games. Examples: Meta Touch, Valve Knuckles, PS VR2 Sense.

**Hand Tracking**
Camera-based recognition of bare hand and finger movements — no controllers required. Increasingly common in modern headsets.

**Haptic Feedback**
Vibration or force feedback in controllers (or gloves) to simulate tactile sensations — feeling a surface, a hit, an impact, etc.

**Gaze / Eye Tracking**
Detecting where the user is looking. Used for UI interaction, foveated rendering, NPC awareness, and accessibility features.

**Teleportation Locomotion**
A movement technique where users point and teleport to a location instead of physically walking. Reduces motion sickness compared to continuous movement.

**Continuous / Smooth Locomotion**
Moving through the virtual world with a thumbstick, like a traditional FPS. More natural but can cause motion sickness in susceptible users.

**Comfort Vignette**
A vignette (darkening of peripheral vision) applied during locomotion to reduce motion sickness by narrowing perceived movement.

---

## 🖥️ Rendering & Performance

**Foveated Rendering**
Renders the center of the image (where the user is looking) in full resolution, and the periphery at lower resolution. Significantly reduces GPU load. Requires eye tracking for "Dynamic Foveated Rendering."

**Fixed Foveated Rendering (FFR)**
A simpler version that always renders a fixed center region at full res, regardless of gaze direction. Used on standalone headsets like the Quest.

**Reprojection / ASW / ATW**
Techniques that synthesize intermediate frames when the GPU can't hit the target frame rate. ASW = Asynchronous SpaceWarp (Meta), ATW = Asynchronous Timewarp. Reduces judder but can produce artifacts.

**Render Resolution / Supersampling**
Rendering at a higher resolution than the display and downsampling to improve sharpness and reduce aliasing. Common to render at 1.2–1.5× native resolution.

**Target Frame Rate**
VR requires consistently high frame rates to prevent nausea and judder. Common targets: **72Hz, 90Hz, 120Hz**. Dropping frames is particularly noticeable and disorienting in VR.

**Single Pass Stereo / Multi-View Rendering**
A GPU optimization that renders both eye views simultaneously in a single pass rather than twice, reducing CPU/GPU overhead.

**Passthrough**
Camera-based video feed of the real world shown inside the headset. Used in Mixed Reality (MR) and as a safety feature. Can be B&W or full color depending on hardware.

---

## 🌐 Spatial Audio

**Binaural Audio**
3D audio technique that mimics how sound reaches each ear differently based on direction and distance, creating spatial audio cues without surround speakers.

**HRTF (Head-Related Transfer Function)**
Mathematical model that describes how sound is modified by the shape of a person's head, ears, and torso. Used to render convincing 3D audio in VR.

**Ambisonics**
A full-sphere surround sound format used in 360° video and VR. Commonly encoded in first-order (FOA) or higher-order (HOA) formats. Rotates with head movement.

**Occlusion / Propagation**
Audio simulation where sounds are muffled through walls (occlusion) or realistically bounce and travel through environments (propagation/reverb).

---

## 🏗️ Development & Platform Concepts

**SDK (Software Development Kit)**
Platform-specific libraries and tools for building VR apps. Examples: OpenXR, Meta XR SDK, SteamVR SDK, ARCore, ARKit.

**OpenXR**
An open, royalty-free standard by Khronos Group for VR/AR runtimes and input. Allows developers to target multiple platforms (Meta, Valve, Microsoft, etc.) with a single API.

**XR (Extended Reality)**
Umbrella term covering VR (Virtual Reality), AR (Augmented Reality), and MR (Mixed Reality).

**AR (Augmented Reality)**
Overlaying digital content onto the real world, seen through a transparent display or camera passthrough. Examples: Microsoft HoloLens, Apple Vision Pro in AR mode.

**MR (Mixed Reality)**
Blending digital and real-world objects so they interact. The digital layer is aware of and responds to the physical environment.

**Comfort Rating / VR Comfort Scale**
A rating system (e.g., Comfortable, Moderate, Intense) used on storefronts like the Meta Quest store to indicate how likely an experience is to cause motion sickness.

**Presence**
The subjective feeling of "being there" in the virtual environment. Considered the gold standard of VR immersion. Broken by low frame rates, poor tracking, or inconsistent physics.

**Locomotion Sickness / Cybersickness / Motion Sickness**
Discomfort caused by a mismatch between visual motion and vestibular (inner ear) signals. A key design consideration for all VR experiences.

**World Scale / Metric Scale**
Setting up your 3D scene so 1 unit = 1 meter in real life. Critical for believable VR — objects and environments that are the wrong scale immediately break immersion.

**Avatar / IK (Inverse Kinematics)**
Representing the player's body in VR. IK systems estimate arm, shoulder, and body pose from just head + controller positions, animating a virtual body in real-time.

---

## 📦 Distribution & Formats

**Standalone VR**
Headsets that run independently without a PC or phone. Processing is done on-device. Examples: Meta Quest 3, Pico 4.

**PC VR / PCVR**
Headsets tethered (via cable or wireless streaming) to a PC for higher fidelity rendering. Examples: Valve Index, Varjo Aero.

**Sideloading**
Installing apps on a standalone headset outside of the official store — common for development builds and indie/beta testing.

**APK**
Android application package format. Since standalone headsets (Quest, Pico) run Android, VR apps are distributed as APKs.

**WebXR**
A browser-based API for delivering VR/AR experiences via the web without needing a dedicated app install.

---

*Last updated: 2026. Generated by Claude Sonnet 4.6 the 2/22/2026. This glossary covers terms relevant to real-time VR game development as well as 360°/180° immersive media.*