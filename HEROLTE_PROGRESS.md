# HEROLTE (Galaxy S7 SM-G930F, Exynos 8890): progreso

## 2026-11-17: 0352 baseline recovered; 0353 building on ARM runner

- The Intel job 43917355519 remained queued for over eleven minutes and
  was cancelled. Same source e8dd573 is building in 43919249542 on macos-15
  (ARM64), temporary branch rearcam-surface-use-builder. Compilation began
  17:31:56 UTC; no new kernel has been installed yet. The private watcher
  now targets that run and artifact xnu-kernel-macos-15.
- diagnostics/surface-use-baseline/ was recovered read-only after automatic
  recovery. The real IOSurface API test reproduces four failures: local
  increment/nested counts work, but shared IsInUse remains false, including
  while the second process holds a use. Initial/balanced/child-death checks
  pass. This establishes the missing protocol, not its causal relation to
  image corruption.
- User exercised home scrolling and manually opened Weather. CPU snapshots
  show substantial early diagnostic overhead: hero-oslog peaks near one
  core and diagnosticd at 171%, while widget startup also consumes CPU.
  The later samples settle substantially. These are top-eight process CPU
  snapshots, not frame-time measurements, and do not establish the UI
  stutter's sole cause. The next focused image trial disables both live log
  streams to avoid repeating that observer load.
- Actual Weather.app now appears in the recovered log. It misses forecast
  caches, starts WDS requests, and begins JWT generation with the correct
  bundle ID. A separate HTTP 200 response is 3376 bytes; no forecast decode
  or JWT completion is established. Cloud No-account messages still do not
  prove why native manual-city forecasts fail. KST remains correct.
- The next bounded trial will compare the same existing HEIC original and
  the shared-use API with herosuse=1. Photos are preserved. Untimed normal
  handback and actual image/UI/Weather success remain outstanding.

## 2026-11-17: current-kernel UI/Weather baseline running during 0353 CI

- 0353 CI 43917355519 at e8dd573 was submitted 17:20:35 UTC and is queued.
  Private finish-build.py watches it; no 0353 artifact/install exists yet.
- Added an opt-in real IOSurface protocol regression: nested local use
  counts, shared IsInUse visibility, a second process using the same ID,
  and cleanup after that child is killed without decrementing. This tests
  the actual framework/kernel API, not a duplicate arithmetic model.
- Added read-only process CPU snapshots (top 8 every five seconds), with
  100% meaning one core. Uses matching 96-byte PROC_PIDTASKINFO and compares
  Mach-tick CPU deltas with mach_absolute_time; this XNU's fill_taskprocinfo
  returns Mach ticks, so assuming nanoseconds would misreport S7 usage.
  No process priorities or frequencies are changed by the observer.
- Weather launch now retries six bounded attempts, keeping composed logs
  around the attempts. Still requires actual launch/forecast validation.
  New diagnostic helpers/probe compile with warnings as errors and are signed.
- While CI queues/builds, installed a current-0352-kernel baseline with
  420-second recovery, 340-second primary Weather logging, 180-second detail
  logging and a 400-second parent watchdog. BOOT
  fed580590c12b388b19dcb79773eae4ff57413c7e150d98b5ae360765cca3d1e;
  predecessor was the verified HEIC/Weather trial. Readback checks pass.
  Actual reboot request 2026-11-16 17:25:55 UTC (Nov 17 02:25:55 KST).
- This baseline does NOT contain the new shared-use fix, has no automated
  shutter/touch input, and preserves saved photos. Runtime files in
  surface-use-0353/baseline/; recovery evidence will be
  diagnostics/surface-use-baseline/. User home-scroll/Weather observation
  and the API/CPU logs are pending. Untimed handback remains outstanding.

## 2026-11-17: direct phone decode corrupt; shared IOSurface-use protocol missing (0353)

- Focused trial returned; diagnostics/heic-weather-0352/ recovered. Both
  full 4032x3024 file-backed phone bitmaps exhibit displaced/stair-stepped
  512-pixel tiles, while the same original is coherent on the host. Both
  decoder children exit 0. VCPHEVC decoder registration also returns 0 but
  does NOT fix the bitmap. This reproduces corruption before Photos/GPU
  display; do not call it a screen-compositor-only bug.
- Weather again failed to launch (mobile workspace false, SpringBoard 3).
  The 140-second composed logger captures Widget and fairplay, but no live
  Weather app/forecast request. This is a diagnostic-launch failure, not
  evidence that the forecast succeeded or that cloud No-account is its
  sole blocker. Actual Weather.app Info confirms com.apple.weather.
- Read only small ranges from the installed arm64 shared cache using HFS
  mapping metadata, Mach-O export trie and Apple dyld_cache_format.h. Local
  LLVM disassembly of IOSurface exports/client implementations verifies:
  IncrementUseCount notifies trap 0 only at local 0->1, decrement trap 1 at
  1->0, two categories 0/1. IsInUse reads a shared u64 at state offset 0x18.
  The current kernel accepts BOTH traps as no-ops, so the shared in-use
  indication never updates. This is a concrete missing protocol, a plausible
  premature-pool-reuse cause; it is not yet proven the HEIC corruption cause.
- 0353 implements per-client active-category bits and atomic shared counts
  at 0x18/0x1c. Duplicate transitions are idempotent; invalid categories and
  unknown IDs fail. Releasing/closing a client removes its outstanding
  contributions before dropping the surface, avoiding leaked use counts.
  Existing lock order (client then global surface lock) is preserved.
- Initially opt-in herosuse=1; default preserves existing behavior. Single
  kernel C++ object compilation and application to the 0352 baseline pass.
  Full CI and real API/pool/decode regressions remain pending.
- Private code ranges, disassembly, runtime addresses and all image files
  stay in rear-focus-0352/surface-cache/ and diagnostics, outside Git. REA
  native provider was unavailable earlier; evidence here is local LLVM
  disassembly, not a claimed REA/Ghidra decompilation.
- User clarifies graphics stutter also affects home paging/app scrolling.
  Camera 8-10 fps alone does not explain that. Add runtime CPU/frame timing
  observation without claiming an established UI performance improvement.
  Normal untimed handback is still outstanding.

## 2026-11-17: focused decode/Weather trial rebooted

- Installed and readback-verified the SAME 0352 kernel/ADT with 360-second
  recovery and no herobot. BOOT
  8240411b811ae9fb39b9a397049f07d696af91424525a3674c2889fde991f5a0;
  drop f7ac12c4f0dfdce2640b17e4564a976ec2a9471d4b0970bfeb804d6e1de4978e.
  Reboot requested 2026-11-16 17:03:08 UTC (Nov 17 02:03:08 KST).
- Runtime 2d5c425 requests two bounded bitmap decodes of IMG_0003 only,
  retaining all original photographs. Baseline versus local software-decoder
  registration are separate children with file-backed output. No decoder
  hook has been injected into Photos or system services by this experiment.
- Automatic Weather launch follows Wi-Fi wait and clock refresh; composed
  logging includes all Weather/weatherd/Widget/fairplay messages for 140 sec.
  Public-website probes are skipped here because they do not establish
  actual forecast success and consume the observation window.
- Read-only pull to diagnostics/heic-weather-0352/ is waiting for recovery.
  Bitmap/Weather outcomes are pending; no successful display fix or weather
  forecast is claimed. Normal untimed handback remains outstanding.

## 2026-11-17: three HEIC originals valid on host; phone display path isolated

- Recovered TWRP after user replug and native ADB backend restart. Verified
  TWRP 3.6.2_9-0/herolte. No photo-file or database writes were made.
  Private evidence: rear-focus-0352/saved-photo-diagnosis/.
- DCIM contains IMG_0001..0003.HEIC (190528 / 167568 / 151538 bytes), with
  three asset rows in copied Photos.sqlite+WAL. All three ImageIO host
  decodes succeed at 4032x3024. Visual inspection shows coherent room/fan
  images, no rectangular tile scrambling. The image is still soft; this
  does not establish completed optical-focus calibration.
- User's attached phone-screen photograph visibly shows repeated/displaced
  image rectangles. The HEIC originals have 512x512 HEVC tiles. Original
  capture/encoding/persistence now works, while the phone's decode/display
  path is faulty. Do not attribute tile scrambling to focus or corrupt
  stored image data. Matching boot logs include PHFigDecoder async failures
  and Camera YUV preview-to-BGRA/JPEG thumbnail conversion failures.
- Mobile-user app launch now succeeds; the synthetic shutter press/release
  returns 0/0. Kernel logs AK7371 initialization/readback plus actual app AF
  sweeps and lens positioning. This is stronger than ID-only evidence, but
  physical sharpness remains incomplete and user confirmation is absent.
- Added a bounded diagnostic-only ImageIO probe for the existing third
  original: a full bitmap goes to file-backed storage; second fresh process
  may register the installed software HEVC decoder only when all exports
  exist. Registration stays within that child, not system apps/services.
  Comparing those bitmaps with host decode will separate decoder behavior
  from Photos rendering. Both children have a 20-second parent deadline;
  originals and library are preserved.
- A focused trial also captures all composed Weather/weatherd/Widget/
  fairplayd log messages for 140 seconds after Wi-Fi/clock refresh, retaining
  privacy defaults. This extends the old 45-second/error-only capture that
  missed the JWT request outcome. User still reports manual Weather absent;
  no forecast success is claimed. Previously seen cloud No-account errors
  alone do not establish the final forecast failure.
- Prepared heic-weather/ uses same 0352 kernel/ADT, timed recovery 360 sec,
  no herobot or synthetic camera capture, 300-second primary logger and
  350-second parent deadline. New probe builds with warnings as errors.
  Installer checks the actual mobile-drop predecessor and full BOOT backup.
  Trial installation/reboot result follows; normal handback still pending.

## 2026-11-17: user reports a saved photograph with broken display

- User now clarifies that a newly captured photograph appears in Photos,
  but opening it looks broken. Treat this as a physical user report of
  persistence progress; the corresponding DCIM original and database row
  have not yet been recovered/validated. Do not equate this with the older
  zero-file snapshots, which preceded this report.
- The mobile-launch drop installer DID finish successfully at 15:34:37 UTC,
  retaining 0352 BOOT d1b2cef9... and readback-verifying drop
  5ddd018ff798a01f6abed2af75fb6059f3165a0a287a34d607de090f135b66f2.
  No subsequent reboot was issued by this agent before the user's update;
  user currently reports iOS, while ADB shows no device. Await recovery
  before further writes. User said to continue.
- Priority is read-only extraction of at most three recent DCIM image
  originals and Photos database/WAL, host decoding/comparison, and the
  matching boot logs. Distinguish malformed/visually corrupt encoded output
  from a phone-side HEIC decoder/Photos rendering fault before changing the
  encoder or capture pipeline. Existing phone images must be preserved.
- Current implementation already had wallpaper HEIC decode failures in a
  different process. This is context only, not proof of the new photo's
  failure mode. No photo-original decode has been inspected yet.

## 2026-11-17: 0352 motor/codec init verified; mobile launch retry ready

- Timed 0352 returned automatically. diagnostics/rear-focus-0352/ confirms
  AK7371 ID 9, initial target 120/511 with readback OK; VCPHEVC software
  encoder registration returns 0. Mobile CFPreferences child reports
  1 -> 0, sync success, uid 501; recovered actual Camera plist has mode 0.
  These are initialization/control results, not a verified focused image
  or encoded/saved photograph.
- No Camera shutter occurred in this boot. User could not inspect Camera or
  rear focus. Root LS workspace still cannot open Camera; SpringBoardServices
  returns 3. Automatic shutter therefore was NOT sent. Both scoped loggers
  exit normally; Media/DCIM/PhotoData remain mobile-owned, 8099 MiB free,
  no DCIM images and zero asset rows.
- Actual /Applications/Camera.app/Info.plist confirms com.apple.camera.
  Next diagnostic launches the app from a fresh uid/gid 501 process using
  the same fork/exec pattern that successfully updated CFPreferences, while
  retaining privileged clock/HID/device work in the parent. It is compiled
  with warnings as errors and signed; actual launch is still unverified.
- USB disappeared after evidence recovery. User confirmed TWRP and replugged;
  recovered connection shows 39% / Charging. A first new install stopped on
  BOOT backup validation before any write. Remote prefix SHA still matches
  d1b2cef9..., and a complete 40 MiB retry at 4096-byte granularity matches
  the current candidate and is backed up. Next script keeps BOOT unchanged
  and changes only the diagnostic drop, after rechecking both predecessors.
- Private next trial: rear-focus-0352/mobile/. The active installed profile
  remains the original 0352 diagnostic drop until this next installer passes.
  Untimed/normal handback remains outstanding.

## 2026-11-17: combined 0352 trial installed and reboot requested

- Full BOOT/drop predecessor checks and backups completed against photo2.
  Timed 0352 BOOT d1b2cef9efa2d7bd87301397377e39a66f18a337b9de9e9a3306f2140461da0b
  and drop 6964f904c78861396bed3c0e2216dcc655be97ed191ac86013bfbce77cbc9fd3
  have matching device readback. Actual reboot request:
  2026-11-16 15:21:20 UTC (Nov 17 00:21:20 KST).
- Kernel source is 29f209f / CI 43891195416; runtime source 9343fc1 includes
  the guarded software HEVC registration, mobile-user Live Photo-off trial,
  longer watchdog/logging and SpringBoard launch fallback. Device behavior
  is pending; do not equate the successful install with iOS/AF/photo success.
- Recovery timer is now 300 seconds (+ flush/reset/recovery startup). Pull
  waits up to 480 seconds and saves diagnostics/rear-focus-0352/, including
  the actual mobile Camera plist and its pre-trial backup for verification.
- User was asked after the real reboot whether ordinary photos persist and
  whether rear focus improves. Those answers are pending. Normal untimed
  candidate and checked handback scripts exist privately but are not run.

## 2026-11-17: 0352 CI passed; HEIC software encoder trial

- CI 43891195416 at 29f209f passed, including the Cortex-A53 no-LSE check.
  Download checksum verification and packaging produce timed BOOT
  d1b2cef9efa2d7bd87301397377e39a66f18a337b9de9e9a3306f2140461da0b
  and normal BOOT
  2997430ab07ca424d31c6f8719f26fcd6cfc14d06b2622d994e2212eed2f09c5
  (18,907,152 bytes). Working BT/ISP ADT is unchanged. The timed cmdline
  enables root-gated synthetic input and returns after 300 seconds.
- Comparing the primary S9 port source exposes another missing still-photo
  dependency: its camera registers Apple's installed VCPHEVC software
  encoder with VideoToolbox because iPhone hardware HEVC encoders are absent.
  Local libnotefecam had no such registration. Added an opt-in cam.soft-hevc
  path, using only system codec/VT exports, guarded for missing symbols and
  dictionary allocation. It logs registration status; no codec binaries are
  committed. This does not itself prove a HEIC/photo can be saved on S7.
- Source adapted from danstronics/ios-s9plus-exynos
  core/userland/src/inject_media.c, register_hevc_encoder (MIT, existing
  gpu/camera/LICENSE.HakiOS). Public primary source URL:
  https://github.com/danstronics/ios-s9plus-exynos/blob/main/core/userland/src/inject_media.c
  The private downloaded comparison file stays outside Git.
- Camera library compiles cleanly with warnings enabled and is signed.
  Upcoming 0352 drop combines software encoder registration, the mobile
  CFPreferences Live Photo-off trial, extended log/watchdog bounds and
  physical AK7371 support. Current installation is being checked against
  the actual photo2 BOOT/drop before writes. Hardware AF, ordinary-photo
  persistence and the SpringBoard launch fallback remain unverified.

## 2026-11-17: save failure reaches Live Photo staging; ordinary-photo trial prepared

- Photo2 returned to TWRP; recovered diagnostics/photo2-0351/. Camera open
  still returned false with a valid LS workspace through all retries, so
  the optional virtual shutter was NOT sent. A real user shutter request
  is present: 4032x3024 StillImage delivered after 211 ms. User confirms
  shutter responds but no photograph remains.
- Primary log captures BWIrisStagingNode reporting insufficient video/audio
  for the Live Photo, followed by Camera Live Photo processing errors and
  `Persistence cannot continue due to a capture error`. There is also a
  photo-encoder completion/error path; its numerical values are absent in
  the primary format-string log. The isolated composed logger ended before
  the user's late capture, so it does not decode that failure. Do not claim
  that ordinary JPEG encoding already works or that Live Photo is the only
  possible blocker.
- Read-only storage inspection: Media/DCIM/PhotoData are mobile:mobile,
  mode 0750; about 8104 MiB free. DCIM has no files and copied Photos.sqlite
  plus WAL reports zero ZASSET rows. This is not a merely missing thumbnail.
- Prepare the next trial with HERO_CAMERA_LIVE_PHOTO_OFF=1. The privileged
  probe backs up the Camera plist, then executes a short separate child as
  uid/gid 501. That child uses CFPreferences to set only
  CAMUserPreferenceDesiredIrisMode=0 and synchronize, logging before/after.
  Original host backup confirms value 1; other preferences stay intact.
  Device application and ordinary-photo persistence still need testing.
- Diagnostic app launch can additionally try SpringBoardServices when the
  LS workspace call returns false. That fallback is not device-verified.
  Extended logging is paired with opt-in HERO_TEST_SECONDS (1..600,
  default 180), fixing the old parent watchdog killing a 195-second probe
  at 180 seconds. Optional log exclusions drop the repeated audio workgroup
  and HAL-property errors so camera/encoding errors retain quota.
- Probe/logger build with -Wall -Wextra -Werror; autorun builds with warnings
  enabled (the existing CommonCrypto MD5 deprecation is suppressed). Signed
  binaries and all private scripts remain in rear-focus-0352/runtime/.
  Upcoming timed trial uses 300-second recovery, 240-second primary logging,
  200-second isolated camera logging, and a 300-second parent watchdog.
- 0352 CI 43891195416 is packaging after the Build step; final CI conclusion
  and actual AF hardware validation are still pending. No 0352 install yet.

## 2026-11-17: photo-only retry and 0352 CI

- Photo-only 0351 returned automatically; diagnostics/photo-0351/ shows
  `open com.apple.camera unavailable` and no Camera process/shutter request.
  Therefore this trial did NOT reproduce the save failure. The isolated
  composed logger itself completes normally; only audio HAL errors appear.
- Probe now explicitly loads MobileCoreServices too, delays until app
  registration progresses, retries opening Camera, and logs whether the
  workspace exists. Optional HERO_PROBE_SHUTTER sends one volume-down
  press/release only after a successful app-open reply plus 15 seconds.
  Synthetic input is kernel-gated by herobot=1 and root; the diagnostic
  runtime compiles with warnings as errors and is ad-hoc signed.
- Installed/readback verified photo2 trial BOOT
  673f176ca4b4fd05b3f2f7d47f81da5f81fab2d42956b9ef6b45b36bd940d528
  using the SAME 0351 kernel/ADT. The bounded cmdline replaces optional
  keepsyms=1 with herobot=1; cpus=8 and all functional boot settings remain.
  Diagnostic-only profile has no automatic RAW sampling or media suspension.
  Reboot requested 2026-11-16 15:03:08 UTC (Nov 17 00:03:08 KST); evidence
  will be diagnostics/photo2-0351/. Save success is not established yet.
- 0352 CI 43891195416 builds 29f209f. Submitted 14:57 UTC, runner started
  15:02 UTC after queueing; currently compiling. No 0352 phone write yet.
- Normal handback must remove herobot, automatic key/app tests and the
  timed recovery boot. Current phone is still an explicitly timed trial.

## 2026-11-16: native RAW recovered; photo saving and rear autofocus unresolved

- Timed 0351 boot returned to TWRP automatically. Evidence recovered in
  diagnostics/front-native-0351/. Native front stream is 2608x1960 with
  all mode writes acknowledged; front RAW sample and gain-32 capture are
  6,389,720 bytes. Later gain-64/repeat phases FAILED: the files at those
  names are stale 1304x980 samples, not new native captures. Many native
  reads were discarded as overwritten during snapshot (e.g. 40/86). Front
  native mode is real but frame delivery/subject sharpness remain unverified.
- Real rear twelve-frame sampling succeeds and Camera receives frames.
  User now reports rear focus is also wrong. Current installed kernel still
  reports NO_FOCUS and has no actuator control. Rear color/video success
  never established working autofocus or still-photo saving.
- User reports photos do not save. This boot has a StillImageCaptureNow
  request and a 4032x3024 NV12 StillImage handed to the graph after 281 ms;
  one photograph counted as delivered, zero output refusals. That is not
  JPEG/HEIC encoding or Photos persistence evidence. DCIM has only .MISC.
- Composed Weather decoder works for type-0x400 records with default privacy
  flags. It exposes cloud-store No account / SyncedDefaults 8888 errors and
  a 200 response of 3,377 bytes; no completed forecast/UI success established.
  Network SNTP refresh and Asia/Seoul +32400 remain verified.
- Installed a photo-only logging drop while retaining timed 0351 BOOT, with
  full BOOT/drop backups and drop hash readback. Actual reboot requested
  2026-11-16 14:52:17 UTC. No automatic RAW sampling, media suspension, or
  mid-test app restart: Camera opens once, stable logging runs alongside an
  isolated composed logger scoped to Camera/media/Photos services. User was
  asked to try one photo. Evidence will be diagnostics/photo-0351/.
- Prepared 0352 AK7371 actuator support. Actual phone DT selects product 12,
  address 0x0c; Samsung enum maps 12 to AK7371. Samsung's on_i2c pins are AP
  gpd2-2/3 with ISP gpc2-4/5 released. Stock pinctrl source confirms gpd2
  offset 0x60. A strict ID=9 and original control/target reads precede any
  motor write. Initial target 120, 9-bit position packing, active mode 0,
  readback and 2 ms settling follow the Samsung driver. Focus commands map
  the existing 0..1023 ABI to 0..511; unavailable/failed hardware leaves
  NO_FOCUS, preserving preview. Saved targets/modes and pin fields restore
  before the existing rear AF rail is restored. No new rail voltages.
- Both affected kernel objects compile, and 0352 applies to 0351. Full CI
  and hardware motor/focus validation are still pending. Do not report AF
  working until actual ID/readback and physical focus behavior are observed.
  Primary source: exynos8895/android_kernel_samsung_universal8895,
  lineage-19.1, fimc-is-actuator-ak7371.c/.h; private copies remain off Git.
- Normal untimed handback is still required; the phone is in a timed trial.

## 2026-11-16: native front trial booted; recovery evidence pending

- CI 43885229677 at f877af3 passed. Verified artifact checksums and packaged
  timed/native 0351 BOOT d4e95e30bd0d29430c72da5884eb480dd4fd8625f1a470d00be18bb680e313f3
  and normal candidate a5bcc2289c60f1b26777cd6b31a951070ff4ba8623b1052b5e6212328f932311.
  The timed image and diagnostic drop were installed with current-image
  checks, full BOOT/drop backup and hash readback; reboot requested
  2026-11-16 14:42:31 UTC (23:42:31 KST). This records the reboot request,
  not a verified successful iOS boot or native camera stream yet.
- Front probe uses file-backed capture storage for the 6,389,720-byte native
  frame, avoiding the anonymous allocation that previously triggered jetsam
  on large rear captures. Native input plus fast cell preview replaces the
  slow 1304x980/full-detail combination for this test.
- Stable Weather format-string logging remains primary. An opt-in separate
  45-second process tries composed/decomposed messages only for Weather and
  weatherd; it may trap independently without killing the system probe or
  primary logger. It retains the default log privacy flags. This decoder
  has compiled with warnings as errors but has not been verified on device.
- User reports front blur across all shooting distances. Rear video/colors
  were confirmed normal earlier; front focus/color and manual Weather remain
  unresolved. Collect evidence from diagnostics/front-native-0351/ next.
- Phone is on timed 0351 and still needs an untimed BOOT/normal profile
  before daily-use handback. All private artifacts stay in s7-port-work/.

## 2026-11-16: 0350 controls verified; native front resolution trial (0351)

- CI 43878704098 at ec1e4fe passed. Installed/readback verified timed 0350
  BOOT 439f3805349bd5c836c6e874d6412e82faefbdb4426423a6f334aff3126bcee7,
  drop c5b90b9e03108aa4a635bfbb822357239dfa91a3c00e238133f2aee88555d1fd;
  reboot 23:04:59 KST. Evidence: diagnostics/front-pair-0350/.
- Paired controls readback is correct (1020/1020 lines, gain 32/32).
  Controlled 512-line RAW capture: gain 32 cell sites TL/TR/BL/BR above black
  = 26.03/13.78/12.98/25.99; gain 64 = 51.74/27.28/25.62/51.58;
  repeat gain 32 = 26.12/13.82/13.00/26.05. All sites scale together by
  ~1.98x. Front app WB stays near 2.02/1.88 around 2x analog gain instead
  of the old 4.14/3.89. User still reports abnormal front / lack of focus;
  this is not a verified complete front-image fix. User clarifies that the whole front image is blurry at every distance;
  this does not establish a simple too-close shooting-distance explanation.
- Exclusive sampling now succeeds: real rear 2016x1512, twelve complete
  reads through sequence 13, saved rear-sample.rwframe (3,810,360 bytes).
  Temporarily stopping media prevents its prewarm reader from switching the
  global source during the probe. Front/gain samples are recovered too.
- Front full demosaic at 1504x1128 costs about 103 ms/render and steady
  preview is ~7.5 fps; it is too expensive as the default. The input is
  only 1304x980. The user did not report resolved sharpness. S5K4E6 has no
  actuator, so physical autofocus cannot be added by this driver.
- Late network clock refresh succeeds via SNTP; UTC is now an actual
  network time, with Asia/Seoul retained. For normal use, the probe can wait
  for Wi-Fi then retry network time without camera tests; a failed late
  retry never replaces a valid running clock with a stale host seed.
- 0351 uses the phone's existing native 2608x1960 4E6 mode table, removing
  the stream's generic SMIA binning overrides. Four 10 MiB front slots need
  40 MiB at 0xd0800000..0xd3000000; rear moves to 0xd4000000 (36 MiB map).
  Verified both ranges fit this phone's reserved camera ION
  0xd0800000..0xdec00000 and overlap no actual ADT RAM bank. No ADT change.
  Front reads take a stable cached snapshot before packing/uiomove, dropping
  a reused slot before exposing bytes. Both kernel objects compile and
  patch application is checked. CI/device trial are pending. Next runtime
  will use the fast cached-cell renderer with this larger native input and
  file-backed front capture storage; no physical-focus guarantee is made.
- Phone is back in TWRP on timed 0350; normal 0350 BOOT candidate is prepared
  (6f0a284bb44305bda560313abef60e469caedc6bda9fef0a96e071342fe7a10c),
  not installed. Native-resolution trial files: front-native-0351/.

## 2026-11-16: 0349 rear works; 0350 front paired controls

- Corrected CI 43872733594 passed. Installed/readback verified timed 0349
  BOOT SHA-256 37b878392a2cbc51c26dc4da7c25bd067730f9315deef9b3ae1d94b91f01f019,
  diagnostic drop 142e3faa9b7010139c9c9ff45149a8ce661ec309ce5b4d9c99f75e56d13055db,
  reboot at 22:26:45 KST. Recovered evidence: diagnostics/rear-device-0349/.
  User confirms real rear video with normal color. Kernel logs physical
  IMX260 stream and 319 reads, with app frames delivered. This is distinct
  from the previous one-shot RAW-only result.
- Automatic rear RAW capture failed: after a valid rear header, another
  reader switched the global device to front and the payload was 1,597,520
  bytes. No rear-sample file was published. Do not call that 12-frame test
  passed. Next diagnostic will suspend mediaserverd during exclusive RAW
  samples, restore SENSOR=2 before closing rear, then resume/restart media.
- User reports front color still incorrect and image out of focus. The
  module's ACTUATOR_NAME_NOTHING confirms fixed focus. The moving-preview
  cell path also discards spatial detail before scaling; full demosaic can
  improve that software blur but cannot add a physical autofocus motor.
- Found a concrete missing S5K4E6 requirement in Samsung's CIS source:
  always set short exposure 0x0202 AND long 0x021e, and short analog gain
  0x0204 AND long 0x0220, even outside WDR. The old port only wrote the short
  pair. Front app WB rises from about 2.05/1.80 at unity gain to ~4.14/3.89
  around 2x; unequal control paths can account for an exposure-dependent
  color bias, but the corrected hardware result still needs verification.
- 0350 mirrors both pairs under group hold and logs periodic readback. It
  also tightens the rear kernel gain cap to Samsung's 8x (code 0x1c0). Local
  object compilation and patch-application checks pass. Full CI is next.
  Runtime AE additionally needs to respect the reported gain/frame limits
  in its intermediate branches and tolerate register quantization; the
  current equality check can stall after a rounded rear gain update.
- Weather now reaches JWT generation, TLS and a network response with
  fairplayd enabled; no completed forecast was established. Cloud store
  migration/sync errors remain. Public HTTPS still succeeds, KST persists.
  Keep this separate from the earlier disabled-service signature failure.
- Phone is back in TWRP, still on timed 0349 and the diagnostic drop above.
  Normal 0349 BOOT candidate SHA-256
  84bad44a60cf56e49a7f6292687c60f9c2625bae96d76b4bb7e6a416a8e67a19
  is prepared but not installed. User authorized continuing the camera work.
- 0350 CI run 43878704098 at ec1e4fe is building. The runtime now enforces
  gain_max and frame_lines_max in every AE branch and accepts small hardware
  gain quantization on readback. Native regression checks cover 960 light
  levels, 8x/1600-line hardware bounds, quantized acknowledgement and stale
  frames; they pass. No new 0350 image has been installed yet.
- Next runtime enables optional cam.front-detail=1: use the existing full
  demosaic/scaling renderer for front video, rather than upscaling 652x489
  color cells to the observed 1504x1128 preview. This retains more detail
  from the 1304x980 input; it does not restore the sensor's native 5 MP mode.
  Host benchmark at 1504x1128/8 tasks: full ~4.8 ms, production cached-cell
  path ~1.4 ms. These are Mac results, not S7 speed claims; device timing
  will be logged. Explicit value 0 disables this option.
- Probe suspends mediaserverd for RAW capture with a finally-block resume,
  restores the front selector before closing the rear descriptor, then
  restarts media for the app. Controlled front captures request 512 lines
  with gain 32, 64, then 32 again, to compare per-site response under the
  paired controls. Private files/scripts/binaries: front-pair-0350/.

## 2026-11-16: KST verified, preview reaches app, physical rear bridge (0349)

- User reconnected after charging: TWRP 8%, 3.841 V, Charging. Installed
  kst-next drop with readback verification and retained the timed 0348 BOOT;
  reboot at 21:31:46 KST. Recovered evidence in diagnostics/kst-0348/.
  The actual localtime target is now Asia/Seoul and Foundation reports
  offset +32400. The untimed/daily-use BOOT has not yet been restored.
- Fresh Camera after media initialization starts its graph, configures the
  PrimaryScaler pool/handler and delivers 160 frames (zero refused), with
  mediaserverd footprint around 100 MiB. User confirms visible video but
  incorrect color; color calibration remains incomplete. Rear is absent:
  the old HAKIOS_CAMERA_SENSOR command only relabeled front frames.
- WeatherWidget logs JWT generation followed by AMSFairPlayGetHardwareInfo
  failure and local-signature failure. Manual-city failure has an additional
  authentication blocker beyond GPS. Public HTTPS still succeeds. Logger
  is stable with guarded argument access but lacks decoded format values.
- Found fairplayd.H2 in the port's disabled list. A bounded comparison drop
  uses a new job label, preserved MachServices, demand start (KeepAlive off)
  and a 60-second throttle. Reboot 21:41:49 KST; service executes and exits
  normally, and Weather requests cached/server data, but forecast success
  is not established. A 250-line/process quota cuts off late Weather logs;
  absence of signature errors in that sample is not proof of authentication
  success. Private current install/evidence: weather-auth-trial/ and
  diagnostics/weather-auth-trial/. That diagnostic drop and timed 0348 BOOT
  remain installed; the phone is back in TWRP.
- 0349 connects SENSOR=1 to the real IMX260/C3 backend; SENSOR=2 to S5K4E6.
  Lazy opens, serialized source changes and last-close shutdown replace
  relabeling. Rear live mode is 2016x1512@30, four 6 MiB DMA slots within
  the existing reserved 36 MiB; stable snapshots are packed into the same
  120-byte header/MIPI RAW10 ABI. Group-held exposure and Sony gain conversion
  serve the app's AE commands. No rear autofocus or full color calibration.
  The IMX260-specific CIS driver declares GR_BG (the generic module's BGGR
  is not authoritative). Use Bayer 1; scene/color evidence remains required.
- Root hero-run preloads the validated companion image before publishing the
  camera device. The camera library selects the physical source before its
  first read. Both edited kernel sources pass local cross-compilation, 0349
  applies to the current 0348 tree, and runtime builds pass (existing MD5
  deprecation warning only). Live ring/frame bounds and RAW10 packing checked.
  Full CI and device behavior are pending. User explicitly said to proceed.
- During CI, verification against the phone's ISP control code and Samsung's
  IMX260 CIS source identified the actual analog transfer function:
  gain=512/(512-code), not the generic 1024-based Sony variant. Corrected
  conversion and reported quantized gain; codes bounded 0..480. Reference:
  exynos8895/android_kernel_samsung_universal8895, lineage-19.1,
  fimc-is-cis-imx260.c functions sensor_imx260_cis_calc_again_code/permile and
  cis->bayer_order. Earlier CI 43871557109 is superseded; no 0349 device
  write has happened. The device remains in TWRP on timed 0348.
- Corrected-kernel CI run 43872733594 at 665dfac is building; the first run
  was canceled before any device install. Private finish-build.py verifies
  SHA256SUMS and packages both timed and untimed candidates. Next install
  script matches the currently installed auth-trial BOOT/drop before writes.
- Added an opt-in physical rear probe: select sensor 1 before reading, check
  API capability, header/2016x1512 dimensions and increasing sequences, save
  12 complete file-backed RAW frames; then explicitly select sensor 2 for
  the front sample. Legacy delayed rcam.level trial will be disabled (-1),
  cam.level=8 loads firmware and publishes the device at startup. Camera
  opens for 30 seconds after the samples; recovery timer stays 240+12 sec.
- Physical switching can change frame dimensions between readers, so the
  runtime validates each frame against its allocation before ISP access.
  Allocation failure and repeated source mismatches stop cleanly.
- Front color remains a hypothesis to test: the 4E6 CIS declares GR_BG,
  while this port programs 0x0101=3 (180-degree readout). For even dimensions
  that can exchange red/blue. Added optional cam.front-bayer (0..3) in the
  library, with value 2 prepared for the next trial, leaving the kernel's
  original RAW metadata available for comparison. Neutral ceiling replay
  gives the expected swapped R/B means/WB gains but cannot establish true
  red/blue order. User has not seen this setting yet. Full CCM/LSC is absent.
- Public sensor reference (specific CIS rather than the generic module):
  https://github.com/exynos8895/android_kernel_samsung_universal8895/blob/lineage-19.1/drivers/media/platform/exynos/fimc-is2/sensor/module_framework/cis/fimc-is-cis-imx260.c
  and fimc-is-cis-4e6.c in the same directory. Private copies stay outside Git.

## 2026-11-16: timed test recovered; KST correction ready, charging

- Runtime commit d171c9e and timed 0348 BOOT were installed with backup,
  upload checksums and readback checks. BOOT SHA-256
  `5f3a6e73da1d5c2c846c00a3cb8c5e53cc6cbae9ce3a97ad17a2a0a5b5e9e835`;
  drop SHA-256 `59ea6267d5a217ab06aa2f5e09edff20f921f458f706b66cebaabb52a2f0d2ba`.
  Reboot requested at 21:16:25 KST; herotwrp logs its recovery request and
  TWRP reconnects around 21:21. The timed BOOT remains installed.
- The streamed rear dump succeeds: 6,096,384 bytes, matching metadata and
  recovered file size. No autorun jetsam. This particular RAW is essentially
  black level (min 61/max 166/mean 64.2); the stretched PNG shows noise, not
  scene detail. Illumination/lens coverage is unknown, so usable photography
  and Bayer color remain unverified. Private evidence: diagnostics/timed-0348/.
- Camera launches and the front reads ~60 frames with measured WB about
  R=1.72/B=2.13, but all delivered/refused counters stay zero. Restart alone
  has not established a working app preview. Next instrumentation records
  graph-running, output configuration/handler/enabled state; it never forces
  delivery into an unstarted graph. The next probe closes any old Camera
  process before reopening it after front setup.
- Logger traps again (status 0x5), after a selected WeatherWidget format
  string is printed; direct argument access is backed out. The guarded
  argument/date/subsystem accessors are retained, with the working typed
  formatString accessor. Automatic Weather open reports unavailable, though
  Weather later executes; no forecast API failure is identified yet. Late
  public HTTPS checks still succeed.
- User reports wrong timezone. Read-only HFS inspection confirms the actual
  localtime symlink points to `/var/db/timezone/zoneinfo/US/Pacific`; zoneinfo
  points to `/usr/share/zoneinfo.default`. Prepared opt-in HERO_TIMEZONE=
  Asia/Seoul changes only that link after validating Seoul's TZif data,
  backs up its old target, resets timezone caches and posts the system
  notification. UTC remains unchanged. This has compiled/signed but is
  **not installed or verified on the phone**.
- TWRP reports capacity 0%, Charging, voltage 3.697 V, current 134. Capacity
  calibration is not established. The user agreed to charge in TWRP for
  10-15 minutes and reconnect. Device is now absent; no more writes/reboots
  during charging. Private next drop and install scripts: kst-next/. The
  installer refreshes the host UTC seed immediately before upload, checks
  current timed BOOT/drop identity, backs them up, writes only the authorized
  drop zone, verifies readback and leaves BOOT unchanged. Next: connect,
  inspect charge/USB, install the next drop and run another timed test; pull
  the timezone/preview/Weather evidence. Restore the untimed 0348 BOOT before
  handing back a daily-use system.

## 2026-11-16: 0348 frame received; bounded dump and unattended retry

- Recovered 0348 console: C3 mode 7 readback agrees, DMA frame-end is
  observed, five frames arrive without SOT/lost-FS/lost-FE/ECC/CRC/DMA errors,
  and slot 0/1 each change all 6,096,384 expected bytes. This establishes
  complete DMA reception, not yet a recovered or displayed photograph.
- Immediately after stage 5, autorun is killed with reason namespace 1,
  code 7 (JETSAM / per-process memory limit). No final dump message occurs;
  the filesystem still holds the older 3,081,584-byte RAW. Stream the frame
  through one 1 MiB buffer instead of allocating its full size; handle short
  writes and EINTR, fsync, then rename the completed temporary file.
- Late probe has an IPv4 address, UTC in 2026, and HTTP 200 for both Apple
  connectivity and weather-data's root page with ordinary TLS validation.
  This does not establish authenticated forecast service success. The user
  still reports manual Seoul unavailable; location/GPS alone cannot explain
  that symptom. The previous logger hit its 200-line cap on locationd.
- The user clarified Camera opens with a black preview. Late front setup
  had omitted the mediaserverd restart used by the normal cam.level=8 path.
  The next opt-in probe restarts it after the RAW sample, briefly opens
  Camera, then retries Weather after clock/network setup and weatherd restart.
  Logging excludes locationd noise and retrieves typed object accessors only
  for log-message records (0x400); runtime confirmation remains required.
- Native runtime builds/signing pass. The existing 0348 kernel and working
  Bluetooth ADT are reused with herotwrp=240 (plus its 12-second log delay).
  The redundant a5fb_perf=1 argument is omitted to fit the boot-argument
  buffer; its compiled default is still 1. This is an unattended diagnostic
  BOOT, not the daily-use image. Private artifacts/backups: timed-0348/.
- Initial timed-image installation stopped during upload after verified
  old BOOT/drop backups, before either partition write; USB went offline.

## 2026-11-16: Weather transport and front-color evidence, next trial ready

- The system probe reports UTC `1970-01-01T00:00:55Z` at start. Both public
  Apple HTTPS checks return `NSURLErrorDomain/-1009` (offline). Wi-Fi later
  joins and exchanges data. These are early-boot observations; they do not
  establish that Weather's later manual-city failure has one proven cause.
  Next probe records interface addresses, retries after the front sample,
  and bootstraps an unset clock from validated-origin SNTP replies, with a
  fresh host UTC seed as the diagnostic fallback. Standard TLS validation
  stays enabled. This is not a completed persistent hardware RTC driver.
- PID fallback identifies `locationd`, but hero-oslog traps with SIGTRAP
  after that sample. Next logger restores `respondsToSelector:` guards and
  restricts message access to type `0x400`, retaining primitive type samples;
  this is a diagnostic change pending runtime confirmation.
- Front RAW recovered: 1304x980, packed RAW10, stride 1630, Bayer 1 (GRBG),
  black 64. Two green sites have nearly equal means (~140 above black); the
  other sites average ~80 and ~67. This is compatible with the declared
  Bayer layout; a neutral scene alone cannot verify red/blue color accuracy.
  The production ISP on this sample starts at WB R=1.075/B=1.109 and reaches
  R=1.716/B=2.035 after 30 frames, settling at 1.751/2.089. Updated ISP seeds
  the first valid measured estimate directly, then uses existing smoothing;
  the same real-sample replay reaches 1.751/2.089 on its first frame. This
  reduces initial green tint; full sensor color calibration is still absent.
- Corrected the donor sensor-name/profile lookup to IMX260/S5K4E6 under
  `/private/var/herolte/`; no fabricated color matrix or lens-shading profile
  was added. Native iOS camera library builds and signs locally; strict
  compile checks pass for both diagnostic tools. A neutral scene and real
  colors in the app still need user verification.
- 0348 CI run `43855092408` passed. Prepared BOOT SHA-256
  `a77b136c8401e0f6d12eb76805eb9f2acf6f64ca4eb75b4e17e1a1fe9342914b`,
  with working Bluetooth ADT/boot arguments retained. Combined drop includes
  clock seed/retry probe, updated front library and `cam.media=1`; the front
  is initialized only after the rear trial stops. USB disconnected before
  the first install attempt. Subsequent attempts stopped on device absence
  or a short BOOT backup read, before any device write. Both LIBUSB and
  NATIVE ADB transports observed disconnects; no causal fix is established.
- At 20:55 KST a stable NATIVE ADB connection allowed BOOT/drop identity
  checks, backups, upload checksums, both writes and readback verification.
  Refreshed the host UTC seed immediately before reboot and verified the
  updated package again. **Reboot at 20:55:40 KST**, installed 0348 BOOT
  `a77b136c…9342914b` and the updated front library / network-clock probe.
  Next: user retries manual-city Weather and front preview after two minutes,
  then returns to TWRP after three minutes for console, test output and RAW.
  These changes are installed but functional success is still unverified.
  Private evidence: `s7-port-work/diagnostics/weather-front-probe/`; install
  receipt/backups: `s7-port-work/rearcam-43855092408/`.

## 2026-11-16: 0347 receives data; full frame and color still unresolved

- Device console after 0347: C3 stream enable ACKs and reads back `0x1`;
  CSIS0 sees its first frame start after ~26 ms, then 5 starts in 188 ms.
  DMA frame-end is observed, with LOST_FE set but no CRC/ECC or DMA error.
  The saved RAW contains 3,081,584 of the expected 6,096,384 bytes; every
  received 16-bit sample is within 0..1023. Host grayscale rendering shows
  initial image content followed by repeated/corrupt patterns. This is
  partial image data, not a complete photograph or working Camera-app rear
  stream. Evidence: `s7-port-work/diagnostics/0347-weather-camera/` outside Git.
- 0348 selects C3 mode 7 to match the sensor, using the firmware's IMX260
  mapping and `0x0042` selector followed by the existing setfile apply command
  `0x6802 = 1`. It retains ADDR1 during active DMA, waits for frame-end, bounds
  subsequent observation for the eight-address ring in each sensor mode, and
  labels incomplete buffer coverage PARTIAL. Apply check passes against
  0346+0347; applied source equals the local compile source. Device trial pending.
- Weather capture: `weatherd` launches and network traffic exists. However,
  hero-oslog saw 197,116 events with every process identified as `?`; its
  process filter therefore produced zero records. This is a diagnostic-tool
  failure, not evidence that Weather made no requests. Work in progress:
  runtime-method accessors plus PID-name fallback, and a read-only system
  clock / public HTTPS probe alongside the logger.
- User reports the earlier front-camera preview was green/magenta tinted.
  The first-boot log identifies the active front frame as 1304x980 but the
  donor library looks for OV16A1Q tuning under `/redwood/fw/`, finds none and
  runs without a color matrix or lens shading. Actual S5K4E6 color correction
  and Bayer validity still need a neutral RAW sample; do not invent calibration
  values or claim this observation alone proves the cause of the tint.
- 0348 CI run `43855092408` at `50035d9` is in progress. It builds only the
  next kernel; no new rear-camera runtime result yet.
- While that builds, locally compiled and ad-hoc signed the updated logger
  and `hero-system-probe` with iPhoneOS clang (`-Wall -Wextra -Werror`, no
  warnings). The logger now obtains object accessors from the runtime method
  table and falls back from missing process strings to PID/sysctl names;
  eight accessor samples are capped independently of filtered output.
  Proxy accessor behavior remains to be verified on the device.
- The system probe starts the logger, records UTC time, performs standard
  ephemeral HTTPS requests to Apple's public connectivity page and the
  unauthenticated Weather data host (an HTTP rejection is transport evidence,
  not successful authenticated Weather access). With `HERO_PROBE_FRONT=1`,
  it subsequently waits until after the rear trial, powers the rear down,
  initializes the front, validates the frame header and writes an owner-only,
  fsynced `front-sample.rwframe` before any color processing. No calibration
  changes have been applied yet.
- Diagnostic drop backup/readback hashes verified, BOOT remains 0347.
  Reboot issued **20:10:04 KST**. User is asked to retry manual Seoul weather,
  offer a neutral scene to the front camera if possible, and return to TWRP
  after about three minutes. Next pull `test.out` and `front-sample.rwframe`.

## 2026-11-16: first rear-camera trial, missing C3 stream enable (0347)

- Recovered console after the Bluetooth fix: bridge traffic reaches 14,524
  bytes to the chip and 36,429 to iOS, with no lost bytes or resyncs. LE
  advertising-report subevent `le02` reaches 431. This establishes observed
  BLE advertising traffic; pairing and application data remain unverified.
- Rear mode 7: C3 ID `0x73c3`, sensor ID `0x0260`, firmware upload CRC
  `0x537b1be7` matches. Sensor global/extra/mode tables have zero NACKs and
  output dimensions read back as 2016x1512. Sensor frame counter reaches 35,
  but CSIS0 counts zero frames; DPHY_STATUS `0xf1` (all stop-state bits),
  DMA byte count zero and both sentinel-filled buffers unchanged. No frame
  file exists; stages 1-4 pass and stage 5 fails. Evidence is retained in
  `s7-port-work/diagnostics/bt-rcam-first/console.txt` outside Git.
- Missing sequence identified by LLVM Thumb disassembly of the phone's ISP
  firmware, SHA-256 `a5a1f0b9243b5ee73243535538848dc973eeb73425c35e6ae0e5995d56473f86`:
  `C73C3_StreamOn` at `0x8354e` writes 16-bit `0x6800 = 1` via `0x12aeb6`;
  `C73C3_StreamOff` at `0x83620` writes zero. Names are linked through literal
  pointers `0x838e4 -> 0x1d7179` and `0x83944 -> 0x1d7188`. Existing code only
  enables the sensor. REA opened the raw target but its required Ghidra
  engine is unconfigured; these are LLVM observations, not REA decompilation.
- 0347 adds C3 enable after receiver setup and before sensor start, logs ACK
  and readback, unwinds on a failed enable, and disables C3 during stop. It
  also refuses to start unverified firmware after a CRC mismatch. Patch apply
  check passes and the applied file equals the locally syntax-checked source
  (1 file, zero failed). Focused disassembly is retained outside Git.
- CI run `43850578499` at source commit `9c7b064` passed (19:52:28 KST;
  approximately 14 minutes including setup and compatibility checks). New
  kernel checksum and the added stream-enable diagnostic string verified.
- Installed BOOT `f79385a9…eca2913` with the already working Bluetooth ADT;
  current BOOT and drop were backed up first, and both new readback hashes
  matched. Reboot issued at **19:53:53 KST**. Camera mode 7 / level 5 remains
  selected; sensor and companion stream-enable ACKs now gate capture.
- User reports Weather says it is unavailable; manually adding a city also
  shows no weather (19:57 KST follow-up). GPS absence alone therefore does
  not explain the reported failure. Maps is not checked. Samsung DTB declares a GPS device, but
  no ported GNSS transport or CoreLocation integration was found (generic
  HID GPS constants are not a driver). `locationd` starts; that alone does
  not establish location fixes. TWRP's 2016 RTC is not proof of iOS's clock:
  the iOS crash directory also contains current-date reports.
- This trial drops the existing signed `hero-oslog` as the test, with a
  165-second Weather/location/trust/network error filter (250 lines). Other
  runtime/camera/Bluetooth entries are retained. User is asked to add Seoul
  manually after the home screen, wait about 3 minutes, then return to TWRP
  for `console.txt`, `test.out` and any raw frame. Actual cause of Weather
  failure and rear-camera output after 0347 are still unproven.
- Repository validation: 35 Python and 12 shell syntax checks pass. Four
  pre-existing patch-number gaps remain. Standard diff header added to 0347;
  its applied source is byte-identical to the CI-compiled implementation.

## 2026-11-16: current SM-G930S installation follow-up

- User reports the first iOS boot reached the home screen and touch works,
  after `XNU MMU ON` and an extended Apple-logo screen. Bluetooth cannot be
  enabled / keeps loading. BLE discovery and connections are not verified.
- Host inspection of the payload used for that boot: its ADT lacks both
  `/arm-io/bluetooth` and `/arm-io/isp`. The root-build tuning script at
  `8c4ab4d430568b5067e53aef82d8c9caec33c034` does not rename the Bluetooth
  launchd job, while `hero-run` still disables `com.apple.bluetoothd`.
  These are configuration findings, not a device-log diagnosis yet.
- Rear-camera commit `7a7c385`: kernel run `43844307826` and mesa-ios run
  `43844312708` both succeeded. Downloaded kernel and runtime checksums pass.
- First-boot console recovered in TWRP: BCM4359C0 responds to HCI, the phone's
  Murata patch loads all 274 records without odd answers, and the UART bridge
  is created. `bluetoothd` repeatedly exits with status 0; bridge counters stay
  at zero bytes in either direction. This supports investigating the missing
  device-tree service; it does not establish BLE scanning or connection.
- Correction to the initial configuration suspicion: the recovered
  `disabled.plist` does **not** disable `com.apple.bluetoothd`, despite
  `hero-run` logging that it wrote its disabled list. The actual launchd job
  still has its original label. Renaming it follows the earlier working port
  configuration and avoids that old code's label, but is not proof that a
  disabled job caused this boot's failure.
- At 19:27 KST, backed up the full current BOOT and existing drop package,
  then installed the new runtime/drop and BOOT; both readback SHA-256 hashes
  matched before reboot. BOOT `8af24ca7…a7d101f` adds only the `bluetooth` and
  `isp` ADT nodes using `add_bluetooth_isp`; other ADT bytes and boot arguments
  are unchanged. The launchd Bluetooth job's key and label become
  `com.herolte.bluetoothd`; all other job contents are preserved.
- Rear-camera trial: mode 7 (default), `rcam.level=5`, `rcam.dump=1`, no
  `rcam.keep`; firmware CRC verified. Kernel stages stop on a failed check.
  `cam.level=0` and `cam.media=0` temporarily disable the front-camera path to
  avoid concurrent use of shared resources. Prior drop entries, including
  Wi-Fi configuration, are retained; runtimes are updated to the completed CI.
- Reboot issued at 19:27:47 KST. The user subsequently reports Bluetooth now
  works (in the context of the previously stuck enable/loading state).
  Pairing, BLE discovery and data transfer have not been separately verified.
  Next: return to TWRP for the persistent console and any
  `rcam-frame.raw`/`.txt`, and decide the next camera stage from actual logs.
  No rear-camera capture has been observed yet. Private backups,
  firmware, plist copies and install receipt are under `s7-port-work`, outside Git.

Registrar por separado: compilación, marcadores recuperados, lo que se ve en
pantalla y comportamiento de iOS. Plan y mapa de hardware en
`docs/herolte-bringup.md`.

## 2026-10-20

- Dispositivo: SM-G930F, bootloader desbloqueado, TWRP instalado.
- `shim/herolte/probe.S` + `probe.c` compilados con Arm GNU Toolchain 14.2.rel1
  (`aarch64-none-elf`): Image de 10.784 bytes, solo relocaciones PC-relativas
  (ADR_PREL_PG_HI21, ADD_ABS_LO12_NC, CALL26), sin llamadas a librería.
  **Solo compilación**; no se ejecutó en el teléfono.
- `tools/herolte-pack-boot.py` probado con una imagen BOOT sintética
  (página de 2048, DTBH v2 con chip 8890): conserva DTBH y ramdisk, copia
  `text_offset`/flags del kernel de stock, recalcula el SHA-1 del header.
  Todavía no se probó con el BOOT real del S7.
- BOOT del teléfono (custom ROM, no stock), leído con `dd` desde TWRP:
  partición de 41.943.040 bytes, página 2048, kernel arm64 sin comprimir de
  38 MB con `text_offset=0x80000`, DTBH v2 con 3 DTB Exynos 8890
  (hw_rev 4–7, 8, 9). DTB: RAM `0x80000000+0x7e400000` y `0x880000000+2G`,
  initrd en `0x82000000`, reservas TIMA `0xb1000000`, ION desde
  `0xc0000000`, módem `0xf0000000`. `0xe2a00000` cae en un hueco libre.
- `probe-boot.img` armado desde ese BOOT (1.495.056 bytes).
- **Primera prueba en el teléfono (reporte del usuario):** el probe muestra
  texto blanco sobre el logo y la cuenta "TWRP EN 60 S"; al terminar, el
  teléfono reinicia solo a TWRP. Prueba que S-Boot ejecuta nuestro Image
  (header arm64 + DTBH correctos), que el framebuffer `0xe2a00000` con el HW
  trigger de DECON_F funciona, que CNTPCT avanza y que el reinicio a
  recovery por PMU `0x105c0000` (INFORM2/INFORM3/SWRESET) funciona.
- **Foto del probe:** EL 1; SCTLR `0x30c5183e` (MMU off); FDT `0x8a000000`;
  IMAGE `0x800bc000`; MIDR `0x410fd034` (Cortex-A53 r0p4); MPIDR
  `0x80000100`; MMFR0 `0x1122` (sin 16 KiB); PFR0 `0x2222`; ISAR0 `0x11120`
  (AES/SHA1/SHA2/CRC32, **sin LSE**); CNTFRQ **0** (como el A5: frecuencia
  desde el ADT, 26 MHz); DECON trigger previo `0x12b0`; initrd
  `0x89000000..0x890dbf7e` (el ramdisk de la ROM).
- Consecuencia: entre initrd y FDT hay 16 MiB, poco para el payload de XNU.
  `xnu_boot` ahora busca el payload pegado a su Image
  (`herolte-pack-boot.py --append`) y usa el initrd solo como alternativa.
- Serie de parches normalizada sobre `xnu-8796.141.3` (ver
  `docs/herolte-bringup.md`): 123 parches aplican con `git apply` simple,
  incluido `0200-herolte-board-target`. 12 movidos a `xnu/patches-pending/`
  (los 10 rotos m?s `0133`/`0134` de GPU del A5, publicados despu?s).
  **El kernel HEROLTE todavía no se compiló**: Actions pendiente.
- `shim/herolte/xnu_boot` (loader) y `tools/mkadt_herolte.py` escritos y
  compilados/ejecutados localmente; sin prueba en el teléfono.
- `0106`/`0107` reescritos como `0201-herolte-amfi-bridge` y
  `0202-herolte-4k-unsigned-dyld-cache`; 125 parches aplican en orden.
- **Primer kernel HEROLTE compilado en Actions** (fork `wardevsa/ios-a5xelte`,
  rama `herolte`, run 39477885586, commit fb6194b): artefacto `xnu-kernel`
  de 61 MB. El chequeo de LSE encontró una sola coincidencia, dentro de
  `K256` (constantes de SHA-256 en `__TEXT`), es decir, datos: el código del
  kernel no tiene atómicas LSE. El chequeo ahora ignora `K256`.
- Actions publica los errores de compilación como anotaciones públicas
  (los logs requieren sesión de GitHub).
- **Primer arranque de XNU en el S7** (`xnu-boot.img`: loader + payload
  pegado de 16.474.720 bytes; kernel sha256 `61a9dd49…ca5d`, cmdline
  `debug=0xc serial=3 cpus=1 keepsyms=1 -enable_kprintf_spam -noprogress`).
  Foto del usuario: consola de XNU en el framebuffer con VM bootstrap,
  zone_init, firehose, scheduler, KDP serial, `iBoot version: herolte-entry`,
  `SWEET PRNG`, `A5XELTE pthread: libpthread-514.100.2 registered`,
  `SWEET AMFI: built-in interface registered`, platform expert iniciado.
  Pánico en `SweetCPU.cpp:86`: `unsupported topology cpu=0 mpidr=0x100
  count=1` (el chequeo esperaba MPIDR 0 del A5).
- `0203-herolte-boot-mpidr`: el MPIDR de arranque es constante de placa
  (`A5XELTE_BOOT_MPIDR`: A5 `0x0`, herolte `0x100`).
- **Kernel completo hasta la espera del root** (run 39481021599, kernel
  sha256 `ffa3d8ea…432f`, misma cmdline). Foto del usuario: `A5XELTE CPU:
  cpu=0 mpidr=0x100 came alive; SGI1 OK`, `1/1 CPUs initialized, SGI1
  verified`, BSD init, AppleKeyStore, IOWatchdog, IOCoreSurfaceRoot, HID de
  botones/touch, SWEET AMFI (0201) y Sandbox registrados, HFS 627.100.6,
  self-tests de Skywalk `PASSED`, `lo0`/`gif0`/`stf0`, y finalmente
  `Waiting on <dict>IOProviderClass IOMedia, Content Apple_HFS</dict>`.
  Es el punto esperado: no hay driver de almacenamiento todavía.
- **Primer probe UFS** (`0204`, run 39484347438, kernel `d3905386…45f2`,
  `ufsprobe=1`): `cap 0x383ff0f ver 0x200 hcs 0x10f hce 0x1 is 0
  utrlba 0x0:ef002000 dbr 0 rsr 1`, `txprdt 0xc rxprdt 0xc nexus 0xffff`.
  El host quedó vivo tras S-Boot y tomó nuestra lista. TEST UNIT READY en
  LUN 0 (3 veces): `ocs 0x7 upiu 0x21 response 0x1 status 0x2`, o sea un
  UPIU de respuesta real con CHECK CONDITION: el transporte (UTRD con
  offsets en bytes, PRDT, NEXUS, doorbell) funciona. El probe no siguió a
  READ porque abortaba tras el TUR. Siguiente: imprimir el sense, probar
  LUN 0..7 y leer LBA1 aunque falle el TUR.
- **Segundo probe UFS** (run 39486812960, kernel `00f0b0da…deb1`): LUN 0–3
  responden NOT READY (sense key 2, ASC/ASCQ 0/0); LUN 4–7 ILLEGAL REQUEST
  ASC 0x25 (no existen: el S7 tiene 4 LU). READ(10) LBA1 en LUN 0: NOT
  READY. Hipótesis: S-Boot deja el dispositivo en un modo de bajo consumo;
  Linux lo reactiva con START STOP UNIT (ACTIVE) al W-LUN UFS Device
  (`0xD0`). `0204` ahora lo hace antes del primer comando (probe e init).
- **Tercer probe UFS: lectura funcionando** (run 39489906319, kernel
  `869c4c5f…d74a`). W-LUN `0xD0` TUR: NOT READY ASC/ASCQ 04/02
  ("initializing command required"); `START STOP UNIT (ACTIVE) 0`; LUN 0–3
  TEST UNIT READY 0; `READ(10) LBA1 0, signature EFI PART`; GPT de 128
  entradas de 128 bytes en LBA 2; particiones p1 `BOTA0` … p17 `USERDATA`
  (~21,5 GB, bloques de 4 KiB). Primera lectura del UFS desde XNU.
- **Primer root montado desde UFS.** Volumen HFSX de 32 MiB
  (`hfs-test-image`, sha256 `043f1459…8b94`) escrito por adb/TWRP al inicio
  de USERDATA (`/dev/block/sda18`); BOOT con `rd=ufsroot0 ufsroot=USERDATA
  cs_enforcement_disable=1` (mismo kernel `869c4c5f…`); ambos verificados por
  readback. Foto: `"USERDATA" on LUN 0: first block 0x22e0ac, 21566 MiB,
  read-only`, `BSD root: ufsroot0, major 1, minor 0`, `hfs: mounted HEROTEST
  on device b(1, 0)`, `root volume is not authenticated (error 25);
  continuing unsealed`, `devfs_kernel_mount: kernel_mount failed: 2` (la
  imagen no tiene `/dev`), y pánico esperado `exec of /sbin/launchd failed,
  errno 2`. Siguiente: imagen raíz de iOS 16.
- **Root de iOS 16.7.16 (iPhone X, D22AP) en USERDATA.** Workflow `ios-root`
  en el repo privado `wardevsa/ios-herolte-root` (la imagen es software de
  Apple; no se publica): HFSX de 20480 MiB, 3 partes gzip verificadas por
  SHA-256. Escrita con `tools/herolte-flash-root.py` (bloques de 64 MiB con
  readback SHA-256, ceros escritos en el teléfono; un corte del servidor adb
  se retomó con el archivo de estado): 320/320 bloques, imagen sha256
  `2e200c51…13ca8`, firma `HX` en el offset 1024. ADT con `/product` real de
  D22AP (63 propiedades) y kernel `d706ccd8…e271` (incluye 0205). Boot:
  `rd=ufsroot0 ufsroot=USERDATA ufsrw=1 rootrw=1 cs_enforcement_disable=1
  unentitled_ios_sim_launch=1 ignition_level=1 launchd_unsecure_cache=1
  wdt=-1 -wdt_no_pmu wdt_test=no_user_checkin`, verificado por readback.
- **Primer arranque de iOS** (log persistente 0206, kernel `012d056a…af10`,
  53 flushes): launchd hace todo el early boot (fsck, mount-phase-1/2,
  keybag, obliteration, launchd_cache_loader con `launchd_unsecure_cache`) y
  llega a `Early boot complete`; lanza SpringBoard, backboardd, keybagd,
  bluetoothd, fairplayd.H2, etc. SpringBoard aborta en loop (24 veces):
  `NSInternalInconsistencyException: We expect a valid bounds for
  configuration ... Main-External ... CADisplay.name = Wireless ... bounds
  {{0,0},{0,0}}` — no había display principal: el `disp0` del ADT decía
  `samsung,herolte-display` y AppleCLCD matchea `samsung,a5xelte-display`.
- **Con el ADT corregido** (boot `67953d9b…ea19`, mismo kernel): `SWEET FB:
  AppleCLCD 1440x2560 stride 5760 at 0xe2a00000 ... presented as 1125x2436`,
  backboardd configura el display (`display on`) y crea superficies
  1440x2560 y 1125x2436; **SpringBoard ya no crashea** (solo CommCenter, sin
  módem, y driverkitd). En ~5 min de log todavía no hay ningún `swap`.
- **Arranque largo (~20 min) con el ADT corregido:** log hasta el flush #37
  (46 KB). backboardd hace `SwapBegin` (sel 4) y sel 52, pero nunca
  `SwapEnd` (sel 5): ningún `SWEET FB: swap`, ninguna registración de
  notificaciones de vsync. El log deja de crecer bastante antes del final.
  `0207`: sampler de hilos (`sweet_sample.c`, SpringBoard/backboardd, a los
  90 s y cada 120 s) y latido `HEROLTE LOG: alive N s` cada 60 s.
- **Muestreos 0207** (kernel con sampler, ~14 min, latido estable cada
  60 s: el sistema no está colgado). Simbolizado contra la dyld cache de la
  imagen: el hilo `IOMFBServer` de backboardd rasteriza con el renderer de
  CPU de QuartzCore (`CA::OGL::SW::scanline`, `vAlpha_Blend` de vImage) y
  reintenta `eagl_init` (busca GPU) en cada `render_for_time`; el hilo
  principal de backboardd queda en `CA::Display::Display::update` (mach_msg)
  y SpringBoard espera en `FBSystemShellInitialize` (check-in síncrono con
  backboardd). Con un solo A53 el primer frame no termina.
- `0208`: SMP en los 4 A53 (MPIDR `0x100..0x103`) por PSCI `CPU_ON`, IPIs
  GICv2 dirigidas por la máscara de ITARGETSR0 de cada núcleo (adaptado de
  los pendientes 0112/0113 del A5). Requiere `cpus=4`.
- **Primer arranque con 4 núcleos** (`cpus=4`, boot `77af8df8…d298`):
  foto `A5XELTE CPU: cpu=1..3 PSCI CPU_ON rc=0 ... came alive; SGI1 OK`,
  `4/4 CPUs initialized, SGI1 verified`; el arranque va notablemente más
  rápido. Log (flush #67, 11 min): el hilo principal de backboardd ya no se
  bloquea; ahora espera en `DMPerformMigration` (XPC síncrono) mientras
  `com.apple.migrationpluginwrapper` aborta (3 veces), y SpringBoard sigue en
  `FBSystemShellInitialize`. CommCenter crashea 45 veces (sin módem). Sin
  `swap` todavía.
- `tools/herolte-tune-ios-root.sh` (en el workflow `ios-root`): como las
  imágenes v12/v13 del donor, `LastSystemVersion` en
  `com.apple.migration.plist`, CommCenter fuera de `launchd.plist`,
  `BKNoWatchdogs` + excepción de watchdog para Setup y el esqueleto
  `/private/var/containers`. `herolte-flash-root.py --diff` reescribe solo
  los bloques de 64 MiB que cambiaron.
- **Root ajustado** (22 bloques reescritos con `--diff`, imagen
  `6e77614c…c156`): sin migración ni CommCenter. **Primer SwapEnd de
  backboardd** (`sel 5`, registro de 1132 bytes), seguido de inmediato por
  `display off` (el driver hace el fundido a negro y no presenta), luego
  `display on`; SpringBoard crea sus primeras IOSurfaces (ids 7–10). Muestreo
  a los ~6 min: SpringBoard en `GSEventRunModal` (UI arrancada), backboardd
  rasterizando en 4 hilos (`CA::OGL::SW::image_sampler`). Siguiente BOOT
  (`a3bce0c3…0758`): `a5fb_keep_on=1 a5fb_noconsole=1 a5fb_perf=1`.
- **0209 (volcado de registros de swap):** los dos primeros swaps son
  frames negros a propósito (`0x104=0x80000007`, todos los ids de superficie
  0, fondo `0x10c=0xff000000`); después no llega ningún swap con contenido.
  backboardd crea sus superficies de render como `0x62336138` ('b3a8', 2
  planos) de 1440x2560 y 1125x2436: la superficie por defecto (panel
  1440x2560) contradice el tamaño presentado (1125x2436).
- **🍎 iOS en pantalla (2026-10-22, boot `a2d97ebe…2239`, `sweetfb_native=1`):**
  con el tamaño real del panel, primero el logo de Apple y después la
  pantalla de configuración "Hola" (bonjour), con hora, batería e indicador
  de inicio de iPhone X. Táctil y botones sin driver todavía.
- `0210`: botones por GPIO ALIVE (`0x10580000`, del DTB del BOOT): Power
  GPA2 pin 4; Vol+/Vol-/Home GPA0 pines 3/4/5, activos en bajo, solo lectura
  con antirrebote (driver del A5 parametrizado). Táctil: `sec_ts` en 0x48 de
  HSI2C `0x14E10000`, IRQ GPA1 pin 0 (pendiente).
- **Botones en el teléfono (boot `8c9c5843…dd25`, 0210):** los cuatro se
  detectan y llegan a iOS (`SWEET HID: key 0xe9/0xea/0x40/0x30`). Power
  bloquea/desbloquea (con `a5fb_keep_on` la imagen queda congelada y al
  despertar vuelve "Hola"); Home y volumen no cambian nada en "Hola"
  (identidad iPhone X: se pasa deslizando hacia arriba).
- `0211`: driver táctil `bsd/dev/herolte_touch.c` (sec_ts en 0x48 de
  HSI2C `0x14E10000`, pines GPF1-0/1 función 2, INT GPA1-0 por sondeo cada
  5 ms; eventos `0x71` de 8 bytes, coordenadas 0..4095 escaladas a
  1440x2560) y `SweetHID` con la geometría del panel del S7. No toca las
  LDO32/33 del PMIC: si no responde, lo deja anotado.
- **0211 en el teléfono:** GPF1 `dat=0` y GPA1 `dat=0` (SDA/SCL e INT en
  bajo), el HSI2C táctil queda en `trans=0x2000c` con el primer byte en la
  FIFO: el sec_ts está sin alimentación después de S-Boot.
- **0212 en el teléfono:** el batcher del PMIC (`0x10550000`) completa el
  envío del registro, pero la lectura queda en `bat_state=0x200` con la FIFO
  RX vacía; no se encendió nada (la verificación de voltaje no llegó a
  correr). `0213`: init del bus como el probe de Linux (reset, master, código
  HS `0x0f`, HS|AUTO), tres formas de lectura (ext de Linux, 7 bits, con STOP)
  y volcado de registros en cada falla.
- **0213/0214:** ambos congelaron el teléfono (0213 tras resetear el HSI2C
  del PMIC; 0214 al arrancar el primer programa del batcher a ~56 s).
- **0215 (sondeo de solo lectura, arrancó bien):** PMU APM
  `config=0x1 status=0x10000 option=0` (M3 alimentado pero retenido, sin
  `ENABLE_APM`), mailbox `0x11240000` todo en 0, SRAM `0x11200000` con una
  tabla de vectores Cortex-M válida (`00004000 0000009d …`): S-Boot deja el
  firmware del APM cargado y el M3 detenido.
- `0216`: alimentación del táctil por el APM, como Linux con la pantalla
  encendida: liberar el M3 (`APM_CONFIG |= 1`, IRQ del mailbox a 0,
  `APM_OPTION |= ENABLE_APM`) y pedirle por mailbox lecturas/escrituras del
  S2MPS16 (LDO32/33). El batcher queda tras `herotouch=2`.
- **🖐 Táctil funcionando (0216, boot `626b33c7…2d1d`):** el APM responde
  por mailbox (S2MPS16 `id=0x2`, `L32CTRL=0x2e`, `L33CTRL=0x3c`;
  escrituras `0xee`/`0xfc` con respuesta `0xa`, readback correcto); con las
  LDO encendidas SDA/SCL suben (`GPF1 dat=0x3`), el sec_ts está en modo app
  (`0x20`, id `ac a5 52`, tx=15 rx=26) y los toques llegan a iOS
  (coordenadas 0..4095 confirmadas). Muy lento y el gesto de deslizar hacia
  arriba no se completa: lecturas I2C con `int=0x400` (NACK) justo después
  de apoyar el dedo pierden los eventos de movimiento.
- `0217`: reintentos de lectura como `sec_ts_i2c_read()` (hasta 10),
  contadores `moves/i2c_retries/lost_reads`; las pausas de 11 s solo con
  `herotouchslow=1` (el táctil queda listo a los pocos segundos).
- **0217 en el teléfono:** `moves=835 i2c_retries=6 lost_reads=0`: los
  movimientos llegan completos; el gesto en "Hola" no avanza porque Setup
  espera CoreTelephony/activación (igual que el donor).
- **🏠 Pantalla de inicio de iOS (2026-10-23):** imagen con Setup marcado
  como completo (imagen `035edb65…d60a`, flasheo diferencial de 155
  bloques): pantalla de inicio y Centro de control con el táctil. Sin apps
  (el staging excluía `/Applications`; dos iconos "Waiting…") y muy lento.
- `STAGE_ALL_APPS=1` en `ios-root` (todas las apps, ~215 MiB) y `0218` +
  ADT `cpu4..7`: los 4 Mongoose (MPIDR `0x0..0x3`) como lógicos 4–7 con
  `cpus=8`.
- **8 núcleos (ADT con `arm,cortex-a53` también en los Mongoose):**
  `8/8 CPUs initialized`; `0219` confirma contador común a los dos clusters
  (lag < 1 ms) y temporizadores que despiertan en los 8 (21 ms sobre 20).
  Los Mongoose reportan `midr=0x531f0011`, `ctr=0x84448005` (línea de
  I-cache de 128 B frente a 64 B en los A53).
- Con todas las apps se quedaba en el logo: `lsd` no terminaba de sembrar la
  base de LaunchServices porque MobileGestalt calculaba el UDID y esperaba
  para siempre `mac-address-bluetooth0` (no estaba en `/chosen`). Con MACs
  sintéticas en el ADT (`02:48:45:52:4f:0x`): **pantalla de inicio con
  iconos** (Fotos, App Store, Ajustes, Teléfono, Safari, Mensajes) y
  Ajustes > Información abre ("iPhone X", iOS 16.7.16, 21 GB).
- **Batería (0220/0221):** el fuel gauge es el del MAX77854 (`0x36` en
  HSI2C_1 `0x13650000`, pines GPD1-2/3; en HSI2C_0 no hay ACK). Lecturas
  reales en el teléfono: 100 %, 4339 mV, +114 mA con cargador; 4043 mV,
  −749 mA sin él; FULLCAP ≈ 2000 mAh. iOS muestra 100 % → 99 %.
- **Botón de encendido (0220):** con `a5fb_keep_on` se acepta el apagado de
  pantalla si llega < 3 s después de pulsar Power; bloquea y apaga la
  pantalla, y vuelve con la pantalla de bloqueo.
- `0222`: `sweetfb_scale=1` experimental, iOS dibuja 960x1706 y el kernel
  escala x1.5 (menos píxeles para el renderizado por CPU).
- **Más RAM (2026-10-23):** el segundo banco de DRAM (`0x880000000`,
  2 GiB, sin `reserved-memory`) para XNU con `mkadt_herolte.py --bank2`.
  Con 2 GiB el kernel ve la memoria pero entra en pánico en
  `kmem_range_init` (no entran sus rangos virtuales). Con
  `--bank2-mb 1024` arranca; los secundarios no llegaban (CPU_ON rc=0 con
  entrada > 4 GiB) y `0223` entra por un trampolín en `0x8fffe000`:
  **1 GiB y 8/8 núcleos**, pantalla de inicio "bastante más fluida, abre
  todo mucho más rápido".
- **0224:** copia a pantalla en paralelo (3 hilos ayudantes): de 10–20 ms a
  ~5 ms por cuadro, hasta 16 fps con movimiento. El log de `kmem` mostró
  por qué 2 GiB no entraba: el kernel (configuración macOS) reserva un
  compresor de 16 × RAM; `vm_compression_limit` lo limita. Con 2 GiB pasa
  ese punto pero entra en pánico en `write_pte_fast` (PTE no alineada,
  páginas de 16 KiB sobre 4 KiB). **Configuración actual: `--bank2
  --bank2-mb 1536`, `vm_compression_limit=98304`, `cpus=8`: 1.5 GiB,
  arranca.**
- **GPU Mali-T880 (0225/0226):** el dominio G3D y los relojes ya vienen
  encendidos de S-Boot; `GPU_ID=0x08802000` (Mali-T880 r2p0), 12 shader
  cores (`0xff0f`), 1 tiler, 1 L2. Con `herogpu=3`: L2, shader core 0 y
  tiler encendidos (ready `0x1`) y **primer trabajo en la GPU**:
  `WRITE_VALUE` en JS1/AS0 con `irq=0x2 mmu=0 exception=1 output=0`, sin
  fallos y sin afectar a iOS.
- **🎨 La GPU dibuja (0227–0230, 2026-10-24):** el descriptor simple de la
  T720 (SFBD) da `DATA_INVALID_FAULT`; con el multi-target de Mesa v5
  (MFBD) y el tiler "desactivado con jerarquía" (máscara 4096, cabecera de
  512 bytes) el fragment job escribe **256/256 píxeles** en memoria
  privada, y con `herogpu=6` **pinta toda la pantalla 1440x2560 de verde
  en 16.6 ms con un solo shader core** (foto del usuario). La copia de iOS
  se pausa 8 s (`sweet_fb_hold_until`) para que se vea.
- **0231:** los **12 shader cores** (`0xff0f`) encienden con la tensión de
  S-Boot y pintan la pantalla entera en **3.26 ms** (5× más que un núcleo),
  estable. `COHERENCY_FEATURES=0`: la GPU no ve las cachés de la CPU, así
  que leer una superficie de iOS exige limpiarla antes (3.8 ms, un núcleo).
  La copia por "preload" del render target da `DATA_INVALID_FAULT`; Mesa
  no usa preload en Midgard (copia con un fragment shader). Copiar con la
  GPU frames dibujados por la CPU no compensa: la aceleración real pasa
  por shaders (primero un triángulo) y, a la larga, por traducir lo que
  pide CoreAnimation/Metal.
- **0232/0233: primer dibujo 3D, un triángulo con shader** (foto del
  usuario). Un tiler job (JS1) guarda el triángulo en la lista de
  polígonos (cabecera 32 palabras, cuerpo 48) y un fragment job (JS0)
  limpia la pantalla y ejecuta un shader Midgard de un bundle, ensamblado
  a mano (`tools/herolte-midgard-shader.py`). Todo en 16 ms. En 0232 no
  se veía nada porque el alpha test fijo de Midgard quedó en NEVER; con
  ALWAYS (0233) el triángulo aparece. Sale casi negro (`02020202`): el
  shader escribe r0 como fp32, y las constantes fp16 1.0 se leen como
  ~0.008. Siguiente: texturas → escalado por GPU (iOS a 720p).
- **0234: primera textura, escalado por GPU** (`herogpu=9`, foto del
  usuario). Una imagen de 180x320 se dibuja como un quad de pantalla
  completa con filtro bilineal: la GPU la agranda 8x a 1440x2560. Sin
  vertex shader, como el preload de Mesa: un varying con coordenadas de
  texel sin normalizar. Shader de 4 bundles ensamblado a mano (ld_vary,
  imov a r28, textura, writeout). Los píxeles leídos coinciden con sus
  texels, y en el borde de un cuadro sale la mezcla del filtro.
  **3.26 ms con los 12 cores** (34 ms con uno). Siguiente: que iOS
  dibuje a 720x1280 y la GPU escale cada frame a la pantalla.
- **0235: iOS en pantalla a través de la GPU** (`sweetfb_scale=1
  sweetfb_gpu=1`). Cada frame de iOS es la textura del quad de 0234:
  ~4.4 ms por frame con la limpieza de caché, sin fallos. Más fluido, pero
  el cuello de botella es CoreAnimation dibujando en la CPU (3-11 fps según
  la pantalla). 960x1706 son 320 puntos @3x, más angosto que cualquier
  iPhone de iOS 16: la interfaz se rompe. 1125x2001 (0236) tampoco sirve:
  UIKit elige la barra de estado por ancho en píxeles y notch.
- **0237:** como syncmodz/ios-s9, el ADT describe un iPhone XR entero
  (`--scale2`: 828x1792 @2x, subtype 1792). La GPU lo dibuja a alto
  completo con barras negras a los lados; el touch se normaliza sobre esa
  franja. Pendiente de probar.
- **0238 (de ios-s9):** los hilos de UI y render van a los Mongoose
  (cpus 4-7) en vez de los A53, y AppleKeyStore responde wrap/unwrap
  (securityd reintentaba sin fin y cada llamada iba al log). Probado:
  más fluido, log de AKS de 1600 a 19 líneas. El XR deja barras negras y
  el Centro de Control sin blur (fondo negro: el blur es de Metal).
- **0239: HeroGPU, etapa 1 de la aceleración completa.** Servicio IOKit
  para que procesos de iOS usen la Mali (GetParam con los números de
  Panfrost, CreateBO/FreeBO/MapBO, Submit). Selftest en el teléfono:
  `GPU_ID 0x880 rev 0x2000 shaders 0xff0f`, un WRITE_VALUE desde un buffer
  de usuario en VA 0x40000000 → **OK en 115 µs**. Siguiente: Mesa Panfrost
  compilado para iOS con un libdrm sobre HeroGPU (como Bergamota con
  freedreno), luego la capa Metal de Chlorophyll.
- **0240-0242: programas de iOS en la GPU.** Zona de "drop" en USERDATA
  (`tools/herolte-drop.py` desde TWRP, el kernel la instala en
  `/private/var/herolte/` cuando la raíz pasa a lectura-escritura; launchd
  corre `autorun`). 0242 corrige `pmap_sync_page_attributes_phys`, que
  truncaba direcciones físicas sobre 4 GiB (panic en MapBO). Probado con
  `herogpu-test` desde iOS: los parámetros de Panfrost, WRITE_VALUE → OK en
  358 µs y un FRAGMENT clear de 64x64 → **4096/4096 píxeles OK en 197 µs**.
- **Etapa 2 (`gpu/mesa`, workflow `mesa-ios`):** Mesa 25.0.7 Panfrost
  (Gallium + compilador Midgard) dentro de OSMesa, compilado para iOS, con
  un libdrm que traduce los ioctl de Panfrost a HeroGPU. `osmesa-test`
  dibuja un triángulo con OpenGL y mide fps; resultado en el log del kernel.
- **Primer OpenGL en la Mali desde iOS.** `GL_RENDERER = Mali-T880
  (Panfrost)`, GL 2.1. Hicieron falta dos arreglos: 0243 configura la GPU
  como Linux para un T880 r2p0 (`SHADER_CONFIG.LS_ALLOW_ATTR_TYPES`,
  clock gate del tiler, throttle del JM), y el libdrm devuelve a Mesa el
  tamaño real del heap del tiler (32 MiB, no los 128 pedidos: el tiler
  escribía sobre otros buffers → DATA_INVALID_FAULT 0x58). Resultado: sin
  fallos, centro rojo `0xff0000ff`, fondo azul, 8192 píxeles del triángulo
  exactos; **256x256 a 159 fps** con `glFinish` en cada frame. Siguiente:
  la capa Metal de Chlorophyll sobre este Panfrost, para CoreAnimation.
- `sweetfb_scale=1` (0222) muestra la imagen rayada y duplicada (las
  superficies a 960x1706 tienen otro formato): queda desactivado.
- Pendiente: nodo `/product` del ADT a partir del IPSW; root (UFS).

## 2026-10-31: aceleración por GPU usable

- Resolución interna de iPhone 8 (750x1334 @2x, `mkadt_herolte.py --iphone8`), escalada por la GPU al panel. La fluidez mejora mucho.
- Boot args: `sweetfb_native=1 sweetfb_scale=1 sweetfb_lw=750 sweetfb_lh=1334 sweetfb_gpu=1 herogpu_mhz=650 herocpu_mhz=2600 herosb=1`.
- Medido: Mongoose 2598 MHz a 1075 mV, GPU 650 MHz. En reposo 7-22 % de 800 % de CPU.
- `hero-run` mueve `BTAudioHALPlugin` fuera de `HAL/`: `launchd` y `mediaserverd` dejan de gastar CPU. La pista es de ios-s9.
- Fondo: imagen fija desde SpringBoard (`herosb.c`, `herosb=1`). No hay proveedores de PosterBoard, la galería sigue vacía.
- Lista de servicios desactivados: `tools/herolte-disabled.list`, copiada como `disabled.list` a la zona de drop. Con 41 servicios SpringBoard no dibujaba: algún servicio de los otros 13 es necesario, sin identificar.
- Gestos: con `home-button-type` 2 aparece la barra roja. Con 1 no hay barra, pero tampoco gestos. Forzar `_UIStatusBarVisualProvider_Phone` en SpringBoard lo hace cerrarse; `gestures.off` en la zona de drop deja esos ganchos apagados.
- `JOB_READ_FAULT` (0x42): tras él ni un trabajo en memoria del kernel corre; no lo curan hard reset ni apagar el dominio G3D. No se vio desde el cambio de resolución, en pocas pruebas. Causa desconocida.
- Falta: límite térmico, audio, Wi-Fi.
## Pantalla a 60 Hz reales (0296-0297)

El bootloader deja el vclk de DECON_F en el oscilador de 26 MHz (`MUX_DISP_PLL`, CMU_DISP0 +0x200, bit 12 en 0): 363 ciclos por línea, 35,8 ms por cuadro, un TE de cada tres, 20 Hz, aunque iOS dibujara 40-50 fps. Con el vclk en DISP_PLL (62,5 MHz): 14,88 ms por cuadro, período 16,74 ms (59,7 Hz), medido con el contador de líneas (DECON +0x8c). Sin relación: eclk, relojes de bus, MULTI_PKT_CNT. Los cortes horizontales siguen: un solo cuadro en memoria, reescrito mientras DECON lo lee.

## Sonido en iOS (0300-0303)

El I2S está en reset hasta `CON_RSTCLR` (+0x00 bit 31); sin eso una escritura traba un núcleo. MOD: OPCLK de PCLK, CDCLK de entrada, esclavo. `heroaudio=3`: `/dev/hakios-audio` antes de que arranque mediaserverd y el plug-in AudioServerPlugIn de HakiOS (`gpu/hakios-audio`, MIT) en `/System/Library/Audio/Plug-Ins/HAL/HakiosAudio.driver`. El kernel alimenta el FIFO a mano, por tiempo. Probado: tono de llamada y teclado por el parlante, barra de volumen.

- **Extensiones, GPU y Wi-Fi (2026-11-01):** el kernel ahora responde la consulta `0x60` de AMFI (idea del kernel del JM21): iOS pasa de 1 a 516 plug-ins y aparecen widgets y fondos. El cuelgue que siguió era un bug propio: la tabla L3 número 176 del pool de usuario caía sobre el nivel 0 de la GPU (`0x8ffc0000`), a unos 350 MB de buffers, y ningún reset lo arreglaba; `0307` le da al pool su bloque en `0x8fc00000`. Wi-Fi: con el orden y los tiempos de Samsung el enlace PCIe sube al primer intento, `14e4:4415`, ChipCommon `0x17094359`. Falta firmware y driver. Pendiente: `CalendarWidgetExtension` usa 2 núcleos unos 7 minutos tras cada arranque y launchd reintenta `AegirPoster`.
- **Wi-Fi escanea (0308-0311, 2026-11-02):** `bsd/dev/herolte_wifi.c` carga el firmware del teléfono (de VENDOR, en la zona de drop, fuera del repositorio) en la TCM como brcmfmac y lo arranca: RTE 9.96.17 en BCM43596 C0. Colas msgbuf en RAM del host (`0x8f000000`, 1 MB), ioctls por la cola de control: `cur_etheraddr`, `ver`, CLM, `WLC_UP`, `event_msgs` y `escan`; el primer escaneo vio 11 redes en 2,4 y 5 GHz. `0310` agranda el io_map a 64 MB. Falta: asociarse con WPA2, el camino de datos y la interfaz para iOS.
- **WPA2 (0312-0313):** con `sup_wpa=1` el firmware responde -23 (BCME_UNSUPPORTED): el de Samsung no trae supplicant (Android usa wpa_supplicant). En 0312 se asocia y el enlace sube, pero el AP lo echa cada ~5 s con razón 15 (timeout del 4-way handshake), 33 s sin claves. `0313` hace el handshake en el kernel como wpa_supplicant: buffers en el anillo rx, un flow ring hacia el AP, nuestro elemento RSN por `wpaie`, PMK por PBKDF2, PTK, MIC, desenvuelto AES de la GTK y claves por `wsec_key`; después un DHCP DISCOVER a broadcast para probar las dos claves. SHA-1/HMAC/PBKDF2/AES escritos en el archivo (el kernel solo trae SHA-256), verificados en una transcripción a Python contra hashlib e IEEE/RFC 3394, y de nuevo en el teléfono al arrancar.
- **📶 Wi-Fi conectado con WPA2 (0313, run 41519331439, kernel `8c2f42a5…acaf`, log `wifi-0313`):** `crypto check: PBKDF2 ok, AES key unwrap ok`, PMK en 18 ms, `wpaie 0`, flow ring 2 abierto, handshake 1/4→2/4 y 3/4→4/4 (GTK índice 1, 16 bytes), `keys: pairwise 0, group 0`, **`CONNECTED with WPA2 in 1649 ms`** (-46 dBm) y **`DHCP OFFER: 192.168.1.25 from 192.168.1.1`** enviada a broadcast: las dos claves funcionan; 3 de 3 frames enviados. Las BOOT de prueba de Wi-Fi (0310-0313) usaban una línea sin `heroaudio=3` (por eso no había sonido); BOOT diaria `xnu-boot-0313-daily` = línea diaria + `herowifi=1`, sin `herotwrp`. Falta: drenar los anillos siempre (hilo), `en0` y Apple80211 para iOS.
- `0314` (en0 para iOS): las capas de apollo (xnu 0128-0135, de HackiOS, APSL 2.0) para el mismo xnu-8796 e iOS 16.7.16: `sweet_net.c` (en0 con la KPI de interfaces), `sweet_sta.c`, `sweet_apple80211.c` (las peticiones de wifid), `SweetWLAN.cpp` e `IONetworkStack` (`SweetNetworkStack.cpp`, con el sustituto del demonio de IOKit; `herowifiquiet=0` lo quita). `herolte_wifi.c` es el enlace y la estación debajo: hilo de servicio (1-5 ms), escaneos y uniones pedidos por wifid, salida de en0 por una cola, la dirección del ADT (`mac-address-wifi0`) puesta en el firmware con `cur_etheraddr`, `network.txt` como red fija. en0 se crea en `bsdinit_task` antes de launchd.
- **🌐 Internet por Wi-Fi en iOS (0314, run 41525337235, kernel `1bb58e29…4649`, log `wifi-0314`):** en0 hecho antes de launchd, `SweetNetworkStack: opened by configd; busy state 0`, la estación conecta sola a la red fija (1727 ms) y `en0's link (the BCM4359) is up`; configd lee SSID/BSSID/AUTH_TYPE; **`en0 so far 9391 frames sent, 11076 received (15154960 bytes)`**. Safari intenta cargar apple.com (parpadea blanco/negro: dibujo, no red). Sin ícono de Wi-Fi: **wifid no se lanza nunca** (ninguna petición de wifid): su job tiene `_LimitLoadToDeviceTree = ("wlan", "marconi-wifi")` y el ADT no tenía `wlan` (apollo, boot 53). `mkadt_herolte.py` agrega `/arm-io/wlan`; BOOT `xnu-boot-0314-wlan` = la diaria con ese nodo, sin probar todavía.
- **Con wlan (log `wifi-0314w`):** wifid arranca y habla (CARD_CAPABILITIES, POWER, RSSI_BOUNDS, escaneos; ícono de Wi-Fi). Safari parpadea: WebContent se lanza 56 veces y muere con `sig 11, pc 0x0`, `lr` fuera de la dyld cache; simbolizado: `WebCore::Document::resolveStyle` → código del JIT de selectores CSS que salta a 0. Calor: `CalendarWidgetExtension` al 200 % varios minutos y `xpcproxy` relanzando WebContent; el kernel en reposo 5-6 %. La línea de arranque diaria + `herowifi=1` pasaba los 607 caracteres y cortaba `sweetsample=-`.
- `0315`: `mmap(MAP_JIT)` rechazado (`herojit=1` lo permite), como para una app sin dynamic-codesigning; Wi-Fi encendido por defecto (`herowifi=0` lo apaga) y en cuanto está `wifi/fw.bin` (antes 45 s fijos); `CalendarWidgetExtension` no arranca (como `AegirPoster`); `WLC_SET_PM` 2 al conectar; el hilo del chip duerme 20 ms en reposo. BOOT: la línea diaria sin `herowifi=1`.
- **0315 en el teléfono (log `boot-0315`):** Wi-Fi a 1 s de tener los archivos, conecta en 1,6 s. `HEROLTE JIT: com.apple.WebKit asks for JIT memory: refused`: WebContent ya no cae en loop (5 lanzamientos, no 56) y llega a dibujar, pero la página se ve **negra**; 2 de 5 mueren con `sig 5` en `_WebContentServiceInitializer` → JavaScriptCore. Rechazar `CalendarWidgetExtension` fue peor: SpringBoard, widgets de Mapas y Game Center al 150-390 % pidiéndolo (todo 800-1300 %). `0316` lo deja arrancar de nuevo.
- **Negro de Safari y fondos que faltan: caché de la CPU.** En `hakios-gl` (eagl.c) una imagen "compartida" (la textura es la memoria del IOSurface) que otro proceso dibuja con la CPU nunca se sincronizaba: `my_glBindTexture` y el bucle de inicio de cuadro saltan las compartidas ("una GPU que tiene la memoria muestra lo que hay"), y la Mali no es coherente (`COHERENCY_FEATURES=0`): lee la RAM vieja. Cada cuadro decía `0 textures refilled`. Ahora `shared_picture_fresh()` limpia la caché del IOSurface (SyncBO de HeroGPU) cuando su seed cambia y cada 30 cuadros. Sin probar.
- **0316 + hakios-gl con limpieza de caché (log `boot-0316`):** las limpiezas ocurren (20 anotadas), pero sigue igual: el fondo original de iOS 16 negro (algunos fondos sí andan) y Safari negro. Los fondos de iOS llegan como **ASTC 4x4** (`0x93b0`, 750x1334, 1004672 bytes): la T880 los acepta sin error y salen negros. `herodrm` ahora oculta a Panfrost los bits ASTC de `TEXTURE_FEATURES0` (20-23; `HERO_ASTC=1` los deja) y Mesa los decodifica por CPU al subirlos. Safari: el registro de creaciones de IOSurface se corta en las primeras 64 del arranque y los selectores se anotan una vez para todos, así que no se sabe qué pide WebKit; `0317` anota aparte las primeras 160 llamadas de WebKit/Safari con su respuesta. Además: `SWEET Sandbox: com.apple.WebKit.Ne privilege 10001 denied`.
- **0317 (log `boot-0317`):** `texture features 0xfffe003f: ASTC hidden` (pero en ese arranque no hubo subidas ASTC). Las llamadas de WebKit a IOSurface: crea superficies sin error (sel 0), puertos (35), sel 20/44/9; el proceso GPU de WebKit dibuja las páginas en superficies de 10 bits **`'w30r'` (750x1024) y `'b3a8'`**, y backboardd nunca hace textura de ningún formato de 10 bits "mostrado" (solo BGRA/RGBA de 8 bits): CoreAnimation sobre nuestro OpenGL ES no los muestra → negro. Causa: `/product artwork-display-gamut = "P3"` (iPhone X). `mkadt_herolte.py` pone `"sRGB"`; BOOT `xnu-boot-0317-srgb` = 0317 con ese ADT, sin probar.
- **Con el ADT sRGB (logs `boot-0317s`, `boot-0317s2`):** PosterBoard pasa a superficies `'BGRA'` (antes `'b3a8'`), pero el proceso GPU de WebKit sigue con `'b3a8'` (23) y `'w30r'` (5); Safari y el fondo original siguen negros. Desensamblado `WebCore::screenSupportsExtendedColor`: usa lo que le pasa el proceso de interfaz y si no, `MGGetBoolAnswer` con la clave ofuscada `Aixt/MEN2O2B7f+8m4TxUA`: la respuesta P3 sigue en la caché de MobileGestalt. `hero-run` borra una vez `SystemGroup/*/Library/Caches/com.apple.MobileGestalt.plist` (`mgcache.gone`); vale desde el arranque siguiente.

## Ideas del S9 (Scion, 2026-11-06)

Scion (fork de HakiOS, Galaxy S9) muestra la imagen sin copiarla (`fb_zc`, su PR 160): la superficie de pantalla de backboardd sale de un pool contiguo bajo 4 GiB y el IDMA de la pantalla apunta a ella en el siguiente refresco; el escalado lo hace el hardware de pantalla (VGF0). Además: `fb_ca_hz=120` (CoreAnimation a 120 Hz) fue su mayor ganancia, y la limpieza de caché de la GPU salta las páginas del pool (dos de 11 MB menos por cuadro). Sus fondos no están documentados.

Para el 8890 (kernel de Samsung `drivers/video/fbdev/exynos/decon_8890`, GPL; copia local en `C:\Users\amanc\herolte\ref`, fuera del repo):
- Canales IDMA: G0 `0x13951000`, G1 `0x13952000`, VG0 `0x13953000`, VG1 `0x13954000` (DISP0); G2/G3/VGR0/VGR1 `0x13e01000-0x13e04000` (DISP1). Los VG/VGR escalan (`VG_H_RATIO` 0x44, `VG_V_RATIO` 0x48).
- Dirección de lectura: `VG_BASE_ADDR_Y(n)` = 0x74 + 4n, sombra en 0xb74; tamaño en `VG_SRC_SIZE` 0x10 / `VG_IMG_SIZE` 0x18; `VG_PINGPONG_UPDATE` 0x1c.
- DECON_F: `WIN_CONTROL(w)` = 0x130 + 0x20w, canal en bits 14:12 (CHMAP); `SHADOW_REG_UPDATE_REQ` 0x60.
- **0320 (log `boot-0320`):** S-Boot usa la ventana 0 → canal **G1** (`0x13952000`): `IN_CON 0xff800000`, `SRC_SIZE 0xa0005a0`, `BASE_ADDR_Y(0) = 0xe2a00000`, sombra igual. G1 no escala.
- **0321-0323 + herosb/hero-run (2026-11-06, sin probar):** de Scion/S9+ (`danstronics/ios-s9plus-exynos`): 0321 hilos de interfaz de un A53 a un Mongoose apenas queda libre (su `sched_slow_secondaries`); 0322 doble buffer en G1 (segundo buffer `0x91000000`, `herofb2=0` lo apaga); 0323 sin timer coalescing (`sweetfb_tcoal=1` lo deja) e `IOMFBDisplayRefresh` 120 Hz (`sweetfb_cahz`); herosb sube a 60 los `CAFrameRateRange` de SpringBoard (`fps.off`); hero-run pasa widgets y demonios pesados a `PRIO_DARWIN_BG` (`widgets.fg`); CPU a 2288 MHz. CollectionsPoster ahora muere por SIGSEGV (`far` = fin de página) sin mensaje: falta simbolizar.
- **0323 en el teléfono (log `boot-0323`, "funciona muy bien"):** `HEROLTE FB2: two buffers` con flips alternando, `timer coalescing off; CoreAnimation told 120 Hz`, Mongoose a 2288 MHz, herosb sube los topes de fps. Sin muertes de jetsam (la RAM no limita hoy).
- **Fondo original (Clownfish):** el plist está bien y los `.ca` existen; `Background.HEIC` (1,4 MB) se decodifica (hero-run: `UIImage {460, 604}`). CollectionsPoster ya no muere en 0323, pero solo crea una superficie de 1x1 y ninguna textura del tamaño del fondo llega a backboardd. El SIGSEGV de 0320 fue en malloc dentro de `-[WKLegacyWallpaperBundleLoader _loadAllValidWallpaperBundlesFromLegacyLocation]` → `wk_colorWithHexString` (intermitente). Siguiente: muestras de `sweetsample=CollectionsPoste,PosterBoard` (BOOT `0323s`).
- Crashes simbolizados (boot-0323, `tools/herolte-dsc-sym.py`): Siri TTS/Kona/MacinTalk excepción en el arranque de PlugInKit (relanzados en loop); MusicWidgets `strlen(NULL)` en `-[MPMediaLibrary _MediaLibrary_coreLibrary]`; PassbookWidgets aserción Swift en FinanceKitUI; assetsd/mediaserverd excepción no atrapada en dispatch.
- **0324-0325 (log `boot-0325`):** límite de CPU de XNU (30 % de un núcleo) para los procesos con "Widge" en el nombre, y fuera los sintetizadores de voz que abortaban en loop: CPU en reposo de 225-290 % a 29-34 % de 800 %, CalendarWidgetExtension de 199 % a ~58 %, 0 crashes de TTS (antes 54).
- **🧠 ~3 GiB de RAM (0326-0329, 2026-11-07, "va de 10"):** port del `1512-sparse-ram-banks` de Scion/danstronics más cuatro arreglos propios del S7, donde los bancos extra están *debajo* del banco de arranque: (1) sin `kprintf` dentro de `arm_vm_init` (el UART se mapea recién en `serial_init`: cuelgue mudo en la etapa 7); (2) `pmap_object` por índice de página, no `pa - gPhysBase` (negativo: `vm_page_insert_internal ... past object bounds`); (3) fuera las zonas que S-Boot da en la línea de Linux y no en el DTB (`ess_setup=0x91200000`, `sec_tima_log=0x200000@0x92e02000`, `sec_avc_log`, `auto_summary_log`; TWRP `/proc/cmdline`); (4) VA de cada banco congruente con su PA (`ARM64_GRANULE_ALLOW_BLOCK`): el shim pagina en 4 KiB y `topOfKernelData` quedaba a 4 KiB de una página de 16 KiB, las sub-tablas de una página nunca se juntaban y fallaba el assert `tt_entry_free` de `pmap_destroy`. Bancos: `tools/herolte-adt-ram-banks.py` (3058 MiB).
- Las superficies de iOS están en el banco 2 (`0x880000000`): el IDMA es de 32 bits, así que no se pueden mostrar directo. Plan: doble buffer propio bajo 4 GiB (ventana libre `0x90000000-0xb0000000`), la Mali dibuja en el de atrás y se cambia `VG_BASE_ADDR_Y` en el blanking. Sin cortes y sin esperar el hueco de 1,9 ms. Después, escalar por hardware en un canal VG.

- **0330-0331 (2026-11-07, logs `boot-0330`/`boot-0331`):** reposo: con la pantalla apagada (Power) 3 s el clúster Mongoose vuelve a la frecuencia y el voltaje del bootloader (MNGS_PLL M=336 P=3 S=2 = 728 MHz, `vdd_mngs 0x3c` = 675 mV, divisores y EMA guardados antes de subirlo) y a 2288 MHz al encender; vsync a 5 Hz con la pantalla en negro. Funciona (`Mongoose to 728 MHz (screen off)` / `to 2288 MHz`). El TEMP del MAX77854 quedó fijo en 28,0 C (lo escribe Android): el límite térmico usa los cuatro TMU (`0x10060000`/`4000`/`8000`/`c000`, sin relojes propios; TRIMINFO bits 7:0 código a 25 C, 15:8 a 85 C; CURRENT_TEMP 0x40 bits 7:0): 31 C al arrancar, 45 C de pico; con 80 C (`herohot`) baja a 728 MHz, vuelve debajo de 70 C.
- **Apps:** `herolte-drop.py app=FILE.ipa|DIR.app` + hero-run (`/Applications` y LaunchServices). Rechaza binarios cifrados (FairPlay, App Store: el IPA de ipatool lo estaba) y los solo arm64e.
- **Blur negro (Biblioteca de apps, Hoy, Centro de Control), en pausa:** el censo de hakios-gl muestra que ds8/vrd/vrb/vcm se dibujan con nuestros programas y solo 61 "edr" y 66 "lub" (pantalla completa) quedan sin dibujar. Cuadro trazado (`gltrace_at` desde `gl.args`): cada recuadro se arma aparte como rectángulo gris (programa 78, 0,7256) y se pega con programa 0 (sin shader de CoreAnimation), coordenadas de textura en píxeles, y después de ese dibujo el framebuffer no se puede leer. El trazado ahora dice qué función es cada dibujo sin programa (hakios-gl a743004): siguiente paso si se retoma.
## 2026-11-12: reinstalación y fondo original

- **Reinstalación desde HyperOS** (backup de BOOT y EFS en la PC): raíz nueva de 4 partes (`e3cc2519…47c5`), drop con las librerías de 0333, BOOT `0331r`. Los primeros arranques se congelaban a los ~3 min: `hero-run` lanza a los 60 s el migrador de LaunchServices y `_LSPrivateRebuildApplicationDatabasesForSystemApps`; `lsd` al 125-130 % y SpringBoard esperándolo. Cortado, `database2.done` no se escribe y la reconstrucción empieza de nuevo en cada arranque. Con BOOT `0325` y sin tocar el teléfono terminó (`database rebuilt: 1`, 515 plug-ins, el hijo sale con 0) y mató de golpe ~29 extensiones (el fondo negro un momento). Después, `0331r` arranca normal. Pendiente en `hero-run`: marcar la reconstrucción hecha apenas vuelve y no matar al hijo a los 300 s.
- **Fondo original:** `CollectionsPoster` sí lo dibuja (superficies `420f` de 512x512 del HEIC, máscaras `L008`, BGRA de 1105x1160). En backboardd llega por `-texImageIOSurface` como superficie sin formato de 1105x1160 (4448 bytes por fila) que el kernel no pudo atar a la memoria del cliente (`not wired, copied`). El censo de hakios-gl (`c9741a6`, log `boot-c974`) la muestra **toda en cero** (1281800 de 1281800 píxeles): la copia se toma antes de que el cliente dibuje. `0332` ata solo las páginas de los píxeles (el tamaño redondeado puede pasarse del final de lo que el cliente reservó) y, si falla lectura-escritura, prueba solo lectura; anota los dos resultados.
- **Galería de fondos negra:** las miniaturas de 400x400 (también sin formato, copiadas) **sí tienen contenido**: ~40-60 % de píxeles en cero, opacidad en el byte 3 (RGBA), medias de color razonables. El negro de la galería viene de más adelante (dibujo o filtros), no de la copia.
- **0332 en el teléfono (log `boot-0332`, kernel `a0cec9c`):** el fondo ahora llega como 1380x1812 (5536 bytes por fila) y el kernel **sí** lo ata a la memoria del cliente, pero solo para lectura (`read-write 0x2, read 0x0`: la memoria del cliente es de solo lectura); los íconos chicos también se atan. El censo sigue en **cero** (2500560 de 2500560): la memoria misma está vacía cuando backboardd la usa, no es la copia. En la pantalla sigue sin verse. Sospecha siguiente: los mosaicos `420f` de 512x512 que decodifica `CollectionsPoster` (HEIC por VideoToolbox, sin decodificador HEVC por hardware en este teléfono) salen vacíos; falta un censo de esos mosaicos dentro de `CollectionsPoster` (libheroapp).
- **Causa del fondo original (log `boot-heic`, libheroapp `21943b5`+):** dentro de `CollectionsPoster`, `Background.HEIC` del pez abre bien con ImageIO (`public.heic`, 1380x1812) pero dibujado en un bitmap da **0 de 2500560 píxeles** distintos de cero: la decodificación HEIC/HEVC sale vacía sin ningún error (no hay decodificador HEVC por hardware y ImageIO no cae en uno por software). El kernel (0332) y hakios-gl ya no son el problema. Arreglo posible: convertir los HEIC de fondos a PNG al armar la raíz (`sips` en el workflow privado `ios-root`, reescribiendo las referencias del `.ca`), o un decodificador HEIC por software (libheif/libde265) dentro de libheroapp para todo iOS (Fotos y apps también).

## 2026-11-12 (noche): fluidez, la CPU y no la GPU

- **Medido (log `boot-heic`, `boot-prof` con `HERO_PROF=1`):** con movimiento la Mali está ocupada 22-29 % del tiempo; backboardd tarda 18-20 ms de CPU por cuadro (~30 trabajos de GPU por cuadro, ~1100 por segundo) y SpringBoard usa 120-160 %. El perfilador de backboardd: `mach_msg2_trap` 32,7 % y `surface_changed` 12,5 %; Mesa entero 13,9 %.
- **0333 (kernel):** `herolte_gpu_submit()` esperaba cada trabajo girando en `delay(10)`; ahora, después de 4 sondeos, duerme de a 50 us (`herogpu_sleep_us=N`; 0 = como antes). Solo para los trabajos de los clientes (`hg_run_nap`); la presentación y las pruebas de arranque siguen girando. **hakios-gl:** `surface_changed()` suma una octava parte de las filas por cuadro, rotando (un cambio se ve en 8 cuadros), en vez de la superficie entera. Commit `8c57e53`, BOOT `boot-0333.img` (receta de `0331r`: loader sacado de su BOOT, `herolte-banks2.adt`, línea de `payload-0331r.bin`; reproduce `0331r` byte a byte).
- **0333 en el teléfono (log `boot-0333`, poco movimiento):** CPU de backboardd por cuadro mostrado de ~88 ms (4 ventanas con >=15 fps en `boot-prof`) a ~60 ms (1 ventana). Muestra chica: hay que repetir con el mismo uso. En reposo `mach_msg2_trap` sigue en ~33 % de las muestras: lo que queda parece ser la copia a pantalla del kernel (`avg_copy_us` 3-5,5 ms por cuadro, ~17 % de un núcleo a 30 fps). Siguiente: presentar sin copia (como el `fb_zc` de Scion) y bajar los ~30 trabajos por cuadro.
- Drop final con hakios-gl `8c57e53` y sin `HERO_PROF`; BOOT `0333`. Teléfono apagado.

## 2026-11-13: presentación dormida y fondos en PNG

- **0334:** el trabajo de escalado de cada cuadro (`sweetfb_gpu=1`, 3-5 ms) también se espera durmiendo (`hgp_draw_locked` desde `AppleCLCD::present()` en el work loop, con solo `hg_mtx`); `herogpu_sleep_present=0` gira como antes. **En el teléfono (BOOT `0334`, drop `6684c12`):** el usuario lo nota más fluido y **calienta menos** que con 0331r/0332.
- **Fondos HEIC como PNG:** `tools/herolte-wallpaper-png.sh` (macOS, `sips`) convierte cada `.HEIC` de `/Library/Wallpaper` a PNG con el mismo nombre; el workflow `ios-root` lo corre y publica `walls.tar.gz` (los de 375w-812h, con `walls/list`). `hero-run` los pone sobre los HEIC desde el drop (`walls/N`, `walls/list`), sin reflashear la raíz. El workflow pasó a `macos-15` (`macos-14` ya no existe: el primer intento se canceló al instante).
- Scion (S9, Exynos 9810) tiene decodificación H.264/HEVC por hardware con el MFC v10 (`drivers/media/mfc/hakios.exynos_mfc.c`, APSL) y pantalla sin copia (`fb_zc`, pool bajo 4 GiB en `hakios.exynos_dpu.c`): candidatos para el S7 (8890: MFC de la misma familia; IDMA de 32 bits como el 9810).
- **🐟 Fondo original de iOS 16 en pantalla (2026-11-14):** `walls.tar.gz` de la release `ios-root-16.7.16-43472966859` (16 PNG, pez y WWDC 2022), rellenados a anchos múltiplos de 8 px (`tools/herolte-png-pad8.py`) y puestos por `hero-run` (log `boot-walls8`: `15 put`; censo en CollectionsPoster `public.png`, 2507808 de 2507808 píxeles con color). El crash de backboardd al abrir la galería (SIGSEGV en el memmove de QuartzCore, imagen de 5128192 bytes) venía de `ask_for_old_wallpaper()` de `hero-run` (SBSUIWallpaperSetImages con el pez): apagado salvo `oldwallpaper.on` (`54b4a00`). Sin crash ahora.
- **Galería de fondos:** sigue con miniaturas negras/blancas. Weather y Astronomy dibujan con Metal. `drawViewHierarchyInRect:afterScreenUpdates:` en vez de `renderInContext` para las vistas previas de PosterBoard (`b988536`, `preview.cpu` vuelve atrás) no cambió nada visible; no crashea. Pendiente: ver si las miniaturas pasan por los filtros/blur (el negro de los blurs) o por superficies del póster.
- **Blur del Centro de Control: funciona** (2026-11-14, el usuario lo ve desenfocado). Rastreos `boot-blur`, `boot-cc*`: las funciones 61 (`edr`) y 66 (`lub`) no son del blur: aparecen en todos los cuadros (ajuste final de la pantalla, valores neutros: `edr` [inf 1], `lub` [0.05 1 1]) y no dibujarlas no cambia nada. `gltrace_draws=N` ahora dispara con N o más (`c6165d1`).
- **Perfil con 0334 (logs `boot-prof2`, `boot-prof3`):** fps máximo 44,4 (antes 38,6); `surface_changed` 0,9 % (antes 12,5 %); GPU 23-33 %. `mach_msg2_trap` sigue en ~36 % de las muestras de backboardd. Llamadas a HeroGPU por 5 s con movimiento (`de36f17`): submit ~4700-5200 (1,65 s de pared, casi todo durmiendo), syncbo 150-175 (180-260 ms: limpieza de caché, ~1,3 ms cada una), create ~50-120 (35-46 ms), map ~50-110 (14-18 ms): ~0,1 núcleo en total; el resto del tiempo en el kernel no es HeroGPU (IOSurface, IOMobileFramebuffer, mensajes de CoreAnimation). La presentación cuesta `avg_copy_us` ~5 ms por cuadro (escalado por la GPU + `dc cvac` de 4 MB) y retiene `hg_mtx` mientras tanto: los trabajos de backboardd esperan. Siguiente: pantalla sin copia con escalado por hardware (VG de DECON_F, superficies de backboardd en un pool bajo 4 GiB), como el `fb_zc` de Scion.

## 2026-11-14: escalado por hardware (VGR0)

- **0335 (log `boot-0335`, solo lectura):** a los 30 s DISP1 está encendido (`status 0x3000f`), VGR0 (`0x13e03000`) parado (ratio 0x100000, IRQ 0x36) y su SysMMU (`0x13e30000`) deshabilitada y bloqueada (`ctrl 0x3`). DECON_F: `RESOURCE_OCCUPANCY_INFO_1 0x100000`, `RESOURCE_SEL_1 0x33033333` (el nibble de VGR0 distinto).
- **0336 (log `boot-0336`):** a los 40 s, SysMMU a `0` (bypass), VGR0 programado como `vpp_reg_8890.c` (750x1334 → 1440x2560, ratios 0x85555/0x85666, coeficientes de `vpp_coef.h`) leyendo una imagen de prueba en `0x92000000`, y la ventana 0 al canal 5 por 8 s. VGR0: `enable 0x4` (OP_STATUS), `irq 0x10001` (**FRAMEDONE**, sin error de lectura ni deadlock); DECON siguió a 60 Hz después (11 cuadros en 200 ms). Nadie miró la pantalla durante la prueba. **Después quedó el logo de Apple para siempre**, con iOS andando por detrás: la prueba coincidió con los flips de FB2 de backboardd; el flip 5 (a FB2) no se tomó, `hfb_give_up` vio la sombra ya en FB y no reescribió `0x74`, y al volver G1 tomó ese flip pendiente: mostró el cuadro viejo de FB2 mientras la GPU dibujaba en FB.
- **0337 (`753a4d6`):** `hfb_give_up` siempre apunta G1 a FB; la prueba corre a los 3 s del hilo de bus (antes de cualquier presentación, y no si los flips ya empezaron) y anota estado de DECON, interrupciones pendientes, ocupación de recursos y una medida de cuadros con VGR0 y de nuevo con G1.- **0337 en el teléfono (log `boot-0337`):** el usuario vio la imagen de prueba (cuatro colores, pantalla completa) y después iOS arrancó normal. Con la ventana 0 en VGR0 el panel recibió un cuadro cada 83,7 ms (75,5 ms leyéndolo, `pend` con bit 8 de FIFO): VGR0 en el oscilador de 26 MHz. De vuelta en G1, 60 Hz.
- **0338 (`dbe14cd`, BOOT `boot-0338b.img`):** los cuadros de iOS van por VGR0. La Mali dibuja el cuadro 1:1 (750x1334, 768 píxeles por fila) en FB o FB2 y VGR0 lo escala al panel, con los mismos dos buffers y flips (registros base/pingpong/sombra iguales a G1). La ventana 0 vuelve a G1 en FB cuando la CPU escribe el panel (copia de respaldo, fundido al apagar) y regresa a VGR0 en un cuadro de GPU posterior (como mucho una vez por segundo); error de lectura o flip no tomado: G1 para siempre. Relojes: los user mux `ACLK_DISP1_0_400_USER`/`ACLK_DISP1_1_400_USER` de CMU_DISP1 (`0x13F00000` +0x200/+0x204, bit 12; `clk-exynos8890.c` de Linux) pasan del oscilador a `gout_top_aclk_disp1_*_400` de CMU_TOP (`herovgrclk=0` los deja). La primera vez se miden los cuadros del panel: menos de 10 en 200 ms, vuelve a G1 para siempre. `herovgr=0` deja el escalado en la GPU; la prueba de colores pide `herovgrtest=1`. **En el teléfono: "más fluido"** (2026-11-14); falta el log.
## 2026-11-14 (noche): vibración y primer paso del decodificador de video

- **0339-0341: motor de vibración.** Del árbol de dispositivos del propio teléfono (TWRP `/proc/device-tree`, copia en `priv\dt-twrp`): `/haptic` pwm_id 1, período 37950 ns, duty 32500 ns, reg2 0x82, regulador `VDD_MOT_3.3V` = LDO34 del S2MPS16; `pwm@136c0000`, TOUT1 en gpd0-5 función 2; relojes del PWM en CMU_PERIC0 (+0x800 bit 8, +0x844 bit 0). El bloque háptico del MAX77854 (0x66, en el bus del medidor de batería, que ahora tiene un candado) como el MAX77705 de Scion (S9). `/dev/hakios-haptic` recibe las muestras del Actuator del plug-in de audio. 0339: S-Boot deja el prescaler 0 del PWM en 0x41 (15 pasos por período) y el motor se rechazaba; 0341 lo pone en 0 (987 pasos de 26 MHz). **El motor vibra** (prueba de medio segundo al arrancar, sentida). `herohaptic=0` sin motor, `herohaptictest=0` sin la prueba.
- **iOS todavía no lo usa.** `mkadt_herolte.py` agrega `/product/haptics` (closed-loop 1, supports-3rd-party-haptics 1, del DeviceTree.d22ap del IPSW 16.7.16); BOOT `0341` con `priv\herolte-banks3.adt`. `hero-run` borra el caché de MobileGestalt cuando cambia `mgcache.token` del drop. MobileGestalt responde `DeviceSupportsClosedLoopHaptics = true`, pero `AudioServicesPlaySystemSound(4095)` (sonda `haptics.probe` en hero-run) no inicia nunca la E/S del Actuator en mediaserverd. Diagnóstico en curso: `hero-oslog` (registro en vivo de logd con LoggingSupport, como test de hero-run) y una prueba de CoreHaptics con sus errores. Scion corre antes `sound_test springboard route`.
- **0340: MFC (sondeo de solo lectura).** `mfc0@152E0000` (ip_ver 0xe, 400 MHz, SPI 302), dominio `pd-mfc` PMU 0x105c4180, dos SysMMU (0x15200000, 0x15220000). En el arranque el dominio está **encendido** (`status 0x3000f`) y `ACLK_MFC_600` habilitado (`enable 0x1`). El firmware `mfc_fw.bin` (778268 bytes) está en la partición VENDOR (copia en `priv\fw`). Referencia: `hakios.exynos_mfc.c` de Scion (MFC v10, 9810) y su decodificador para VideoToolbox (`mfc_decoder.c`).
- Drop: `priv\drop-20261114` (gl.env sin `HERO_PROF`, `mgcache.token`, `haptics.probe`).
## 2026-11-15: el trabajo del Note FE en el S7 (0342-0344)

- **0342:** los parches de kernel del port del Galaxy Note FE (egemengunel/ios-a5xelte, rama `gracerlte`, 76abd2e; el mismo Exynos 8890, que partió de este port en 0331) fusionados a tres vías sobre 0332-0341, en un solo parche. Afuera: 0400 (dirección del panel del Note FE) y 0402 (voltajes ASV de ese chip). Conflictos: el bus del medidor lleva el motor (0339) y el cargador (0406/0411) bajo un candado; `hg_run()` espera la interrupción de la GPU (0415) o duerme (0333). Árbol de trabajo: `merge-notefe2` (fuera del repo), base sacada del buildtree de CI de 0341.
- **0343:** piso de brillo 64/255 (`herobrightmin`): el brillo automático, sin sensor de luz, pedía 1 y la pantalla quedaba negra (boot-0342).
- **0344:** en el S7 la espera por interrupción de la GPU (`herogpuirq`) y la cuenta de llamadas (`notefe_uc`) apagadas por defecto: boot-0342 promediaba 19,5 fps contra 31,4. Sin `herogov` en la línea de arranque; `herocap=coreduetd:20` queda.
- **Cámara frontal: funciona** (S5K4E6; mismos rieles S2MPB02 LDO5/6/7/13 y pines gpc0-4/gpc1-1/gpk0-2 que el Note FE, verificados en el árbol del teléfono). `hero-run` hace la secuencia del bot del Note FE con `cam.level=8` (`kern.notefe_cam=7`, reinicia mediaserverd, MobileGestalt); `gpu/camera` = libnotefecam.dylib, cargada por libheroapp con `cam.media=1`.
- **Bluetooth: funciona** (lista equipos). El módulo del S7 es **Semco** ("BCM4359C0 Grace SWB-B90S" tras el patch `bcm4359C0_semco.hcd` de VENDOR, en el drop como `bt-murata.hcd`). Hizo falta: `bluetoothd` fuera de `heronoexec`, su job con otra etiqueta en `launchd.plist` (drop con destino absoluto; launchd guarda su propia lista de deshabilitados) y el nodo ADT `/arm-io/bluetooth` (`bluetooth,n88`) + `/arm-io/isp` (`priv\herolte-banks4.adt`). BOOT `boot-0344b.img`.
- **El táctil necesita arrancar desde TWRP:** reiniciando desde iOS, la SRAM del APM no tiene su firmware (lo deja Linux/TWRP), el APM no responde y el táctil no tiene alimentación ("no supply").
## 2026-11-15: ¿iOS 18 en el S7? Medido

- **Shared cache de iOS 18.7.8 (iPhone XR, arm64e), `tools/dsc-lse-scan.py` vía `dsc-scan.yml`:** 609 M instrucciones en `__text`; **463.816 atómicas LSE** (iOS 16.7.16 arm64: 990 en 375 M, ninguna en libobjc/CoreFoundation/Foundation/UIKitCore/QuartzCore), 93.674 LDAPR/LDAPUR, **19,6 M operaciones PAC** a reescribir (más 9,2 M en el espacio HINT, NOPs en ARMv8.0). `objc_retain`, `objc_release`, `swift_retain`, `swift_release`, `os_unfair_lock_lock` tienen 1 LSE cada una; `pthread_mutex_lock` 2.
- **Costo de la emulación en el S7 (0345 = v80emu de la rama v80emu-test, `tools/ios/v80stress.c`, log `boot-0345`):** LL/SC nativo 13 ns; LDADDAL emulado **1364 ns (105x)**; LDAPR emulado 1696 ns; una PAC emulada ~1,4 us. Semántica: 31302 comprobaciones sin fallos; 8 hilos x 20000 atómicas mezcladas exactas. 4 fallos en el `si_addr` de las señales por fallo de página (el emulador reporta otra dirección).
- **Conclusión:** emular por trampas los `retain`/`release` (millones por segundo) es inviable; PAC y LDAPR se reescriben 4 bytes por 4 (Renegade de Bergamota; LDAPR -> LDAR); las LSE calientes necesitarían reescribir el cache con saltos a rutinas aparte (las frías pueden quedar en trampas, contando sitios con `kern.v80emu`). Más el kernel xnu-11215 con todos los drivers portados (rama `herolte-ios18`). Grande y sin garantía de quedar usable; el Edge 30 (ARMv8.2, LSE nativo) evita la parte de LSE.
## 2026-11-15 (tarde): iOS 18 en el S7, adelante igual

- **Decisión del usuario:** seguir con iOS 18 en el S7 (20 fps alcanzan; Wi-Fi/BT pueden faltar).
- **Kernel xnu-11215 (rama `herolte-ios18`):** `50fef0c` arregla la compilación (9162: MPIDR_CORETYPE_* en A5XELTE.h, UBSan verifier salteado para HEROLTE; 9079/9084/9095 sin lo que Bergamota ya trae). Compila todo; faltaba el enlace: `b266564` (9163) da stubs a sweet_early_*/sweet_reboot_note_panic y saca SweetAdreno para A5XELTE. Build de b266564 en CI, sin resultado todavía.
- **Cache de iOS 18.7.8 (`tools/dsc-tramp-space.py`, log `logs/dsc-tramp-space.txt`):** 463.816 LSE (ldadd64al 165k, ldadd64 151k, ldadd32* 99k, cas ~37k, casp ~870, swp ~6k). Relleno libre (ceros) entre imágenes: 7,8 MiB en 3836 huecos; dentro de los segmentos: 0. Con rutinas de 64 bytes caben 117.762 (48 B: 148.562); el resto queda en trampas. Hay que ubicar primero las imágenes calientes (libobjc, libswiftCore, libsystem_*, libdispatch, CoreFoundation, Foundation, UIKitCore, QuartzCore); la mayoría de los sitios están en Recon3D, WebCore, AppleCV3D, libusd, VectorKit. Otras clases: LDAPR 93.670, FP16 22.574, FCMA 2.455, SHA3/512 848, FJCVTZS 474, RCpc con desplazamiento 4.
- **`tools/ios18/v80strip.py`:** LDAPR/LDAPUR #0/STLUR #0 -> LDAR/STLR en el lugar; cada LSE -> B a su propia rutina LDXR/STXR (registros temporales guardados bajo la zona roja, NZCV preservado, CASP escribe de vuelta si falla la comparación), LDAPUR/STLUR con desplazamiento -> LDUR+DMB ISHLD / DMB ISH+STUR. `ios-tools` (9a00099) arma `v80stress-r`: 44 sitios reescritos, desensamblado revisado (capstone), ninguna LSE/RCpc restante.
- **Siguiente:** probar `v80stress-r` en el teléfono con iOS 16 (semántica y ns por atómica); modo cache de v80strip con prioridad a imágenes calientes; root de iOS 18 con Renegade (`ref/bergamota/tools/renegade`) + v80strip.
- **Kernel xnu-11215 en el S7 (2026-11-15, rama `herolte-ios18`, root de iOS 16 todavía en USERDATA):** BOOT 18k1/18k2 (`ed5bc42`): sólo marcas 1-7 (la consola A5 se apagaba a propósito en `arm_vm_init`). **9165** deja viva la consola temprana: alias de la pantalla en TTBR1 después de los low globals (con páginas de 4 KiB, `VM_MIN_KERNEL_ADDRESS` + un bloque cae en otra entrada L1 sin tabla; 18k3) y marcas 21-29 dentro de `arm_vm_init`. 18k4 (`baf6902`): pasa todo `arm_vm_init` y `kprintf` (marca 20) y entra en pánico al arrancar los secundarios: `cpu_common.c:855 cpu_signal == SIGPdisabled (0x8)`: la ventana de IRQ de 0208 en `SweetCPU::initCPU` tomaba la SGI propia antes que `processor_cpu_reinit()` de 11215. 18k5 (`cpus=1`, log `boot-18k5`): UFS y root montado, audio (el pitido), Wi-Fi conectado (WPA2), táctil, batería, GPU, APM; `init` queda en `herolte_wifi_early()` sin `en0` (un solo núcleo). **9166** saca esa ventana: 18k6 (`36bc7e8`, 8 núcleos) llega a launchd, y el launchd de iOS 16 sale: `initproc exited -- exit reason namespace 7 subcode 0x1: could not set up inheritance port` (libxpc; el userland de 16 no sirve con el kernel de 18, como se esperaba). v80emu ya estaba en la serie de 11215 (`9157-0400`). Siguiente: la raíz de iOS 18 (workflow `ios18-root`) en USERDATA (el usuario aprobó borrar USERDATA).
- **`v80stress-r` en el S7 (iOS 16, BOOT 0345, log `logs/boot-0345-v80r.txt`): TODO OK, 31.448 comprobaciones, 0 fallos** (los 4 fallos de `si_addr` de la emulación desaparecen: la rutina falla en espacio de usuario con la dirección real). **LDADDAL por rutina 19 ns** contra 14 ns de LL/SC nativo y 1364 ns por trampa; LDAPR -> LDAR 6 ns. Las rutinas de v80strip resuelven el costo de las atómicas de iOS 18.
- `90612e8`: rutinas más cortas (valor viejo directo en Rt cuando se puede: LDADDAL w8,w9,[x10] = 9 palabras) y `tools/ios18/v80strip_cache.py` (cache entero, por prioridad: runtime y UI primero; resto a v80emu; hashes de página recalculados). Plan sobre 18.7.8 en `dsc-scan`.

## 2026-11-16: cámara trasera (IMX260), arranque por etapas (0346, sin probar)

- **Hardware (DTB del propio teléfono `hw9.dts` y el driver GPL de Samsung `fimc-is2`):** IMX260 (I2C 0x34 de 8 bits = 0x1a, registros de 16 bits y datos de 8) detrás del compañero S5C73C3 ("C3", 0x7a = 0x3d, registros y datos de 16 bits, ID `0x0000` = 0x73c3), los dos en el I2C0 del ISP: gpc2-0 SDA, gpc2-1 SCL (Samsung mismo lo maneja por software, `i2c@3d` = i2c-gpio). SPI del compañero: los pines de `spi@143A0000` (gpc3-4/6/7, SSN gpc3-5), manejados por software (el controlador está en el dominio cam1, sus relojes no se tocan). MCLK0 gpk0-0 (sensor) y MCLK1 gpk0-1 (compañero) a 26 MHz (`SCLK_ISP_SENSOR0/1`, CMU_TOP 0xb00/0xb10); reset del sensor gpc1-0, del compañero gpc1-2. Rieles del S2MPB02 (LnCTRL = 0x1d + n, bit 7; LDO1-5 de 12,5 mV, LDO6-18 de 25 mV desde 600 mV; BUCK2 0x0d/0x0e, 400 mV + 6,25 mV): LDO1 0,95 V, LDO2 1,0, LDO3 1,05, LDO4 1,05, LDO7/8/9 1,8, LDO10 1,875, LDO11 1,2 y después 2,875, LDO12/14/15 2,8, LDO17 1,8, BUCK2 0,8 V; un código fuera del rango del DTB se rechaza. BUCK1 y BB (de los que salen los LDO): si están apagados, la etapa 1 los prende con las mismas escrituras que la frontal (0342, líneas 2212-2230 del parche: `0x0c = 0x90`, `0x0b |= 0xc0`; `0x0f |= 0xc0` si BB pide 4,0 V o menos) y la etapa 0 los deja como estaban.
- **Recepción:** CSIS0 `0x14000000` (4 carriles), PHY `phy_cam0_csi` 0x144f1040 (reset bit 1; aislamiento PMU 0x70c bit 0, compartido con el DSI: solo se apaga si lo prendió rcam), SysMMU `0x140e0000` en bypass, relojes de CMU_CAM0 `0x144d0000` (+LOCAL `0x140f0000`): ACLK/PCLK de CSIS0, los cuatro RX_BYTE (mux 0x220-0x22c bit 12), TREX_528; los que estén cerrados se abren y se dejan como estaban. Settle 30 sin deskew (el `config_imx260[7]` de Samsung: modo 7 sin `mipi_speed`); el modo 3 usa 45 con deskew (2145 Mbps). Los dominios cam0/cam1 tienen que estar prendidos (rcam no los prende).
- **Etapas (`sysctl kern.herolte_rcam=N`, root; N corre 1..N en orden, log `rcam:`):** 0 todo abajo (orden inverso de Samsung, rieles, pines y relojes como estaban); 1 rieles + MCLK + resets en el orden y las esperas de `fimc-is-module-imx260.c` (cada riel releído); 2 sondeo I2C0 (compañero 0x0000/0x0002, IMX260 0x0016/0x0017); 3 firmware del compañero desde `kern.herolte_rcam_fw` (CRC32 del archivo menos sus 4 últimos bytes = esos 4 bytes; el orden de los pines SPI, CLK gpc3-4, SSN gpc3-5, MISO gpc3-6, MOSI gpc3-7, se comprueba contra el ID leído por I2C; el orden con MISO/MOSI cruzados, que maneja gpc3-6 como salida, solo con `kern.herolte_rcam_spiswap=1`), subida en tramas de 256 bytes a 0x6F12, CRC del propio compañero, ARM go, versión, setfiles master y mode; se saltan la calibración (LSC/PDAF de la FROM) y el binning de voltaje; 4 tabla global + 5 escrituras extra + modo 7 (2016x1512 a 30, RAW10, 4 carriles; tablas del `fimc-is-cis-imx260-setA.h` público, iguales a las del firmware del teléfono), bypass del compañero `0x003a = 0x0099` releído, sin transmitir; 5 CSIS0, transmisión, el primer cuadro en `0xd1400000` (rango ION de la cámara, detrás de los 10 MB de la frontal; 16 bits por píxel, 6096384 bytes), estado, contador de cuadros, errores y estadísticas del primer cuadro (ADDR1 del DMA pasa al segundo hueco después del primer cuadro, así no se pisa), y fin de la transmisión salvo `kern.herolte_rcam_keep=1`. El cuadro sale por `kern.herolte_rcam_pic_info` (texto: ancho, alto, bytes, estadísticas) y `kern.herolte_rcam_pic` (hasta 1 MiB desde `kern.herolte_rcam_pic_off`), como el `notefe_cam_pic` de la frontal. Opciones: `kern.herolte_rcam_mode` (7, o 3 = 4032x2268 a 60 del firmware), `_settle`, `_deskew` (0 por modo, 1 no, 2 sí), `_bypass`, `_spiswap`.
- **Cómo correrlo:** en el drop, `rcam.level` (0-5) y `rcam-comp.bin` (el `companion_fw_imx260.bin` del propio teléfono; no va al repo): `hero-run` a los 45 s escribe el firmware y pone `kern.herolte_rcam=N`, aparte de `cam.level`. Con `rcam.keep` (cualquier contenido) pone antes `kern.herolte_rcam_keep=1`; con `rcam.dump`, después de las etapas escribe el cuadro en `/private/var/herolte/rcam-frame.raw` (los bytes recibidos, 16 bits por píxel) y `rcam-frame.txt`. Para traerlos, apagar iOS normalmente (hero-run hace `fsync`, el lector no lee el diario de HFS), arrancar TWRP y en la PC: `python3 tools/herolte-hfs-read.py get /private/var/herolte/rcam-frame.raw rcam-frame.raw`, lo mismo con `rcam-frame.txt`, y `python3 tools/herolte-rcam-raw2png.py rcam-frame.raw --txt rcam-frame.txt` (PNG en grises sin interpolar: el orden Bayer no se sabe). El lector solo lee (`dd` de `/dev/block/sda18` por `adb exec-out`) y no maneja archivos comprimidos (decmpfs); este no lo está. Empezar por 1-2, después 3, 4, 5; terminar con `kern.herolte_rcam=0`. No usar a la vez que la frontal (comparten el bus del S2MPB02 y el banco gpc2; LDO7 es de las dos).
