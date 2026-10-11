# Source provenance

Reflector baseline: https://github.com/EdHasley/Extended_Name_Reflector
at commit `a8cf2c9f73440fbfc2018aa3a701ba1671009650` (retrieved 2026-10-11).
No write was made to that repository.

Software vocoder: https://github.com/nostar/DroidStar
at commit `28b10be62b4c7b53c6720a0f083e8ee7a450effb` (retrieved 2026-10-11).
The `mbe/` and `imbe_vocoder/` directories are bundled under `vendor/`.
The Qt user interface and the optional MD380 firmware backend are not included.

The imported codec contains ISC-style mbelib/MBEVocoder notices and GPL notices
in the Pavel Yazev IMBE implementation, with original author information retained
in each file. Doug McLain maintains DroidStar. The AF0WX service, tests and build
integration are provided under GPL-3.0-or-later (`COPYING`). Consult the original
source-file notices for component terms; no ownership of upstream work is claimed.

Local vendor edit: initialize `error` and `error_index` in `mbevocoder.cpp` to
remove possible-uninitialized compiler warnings. The AMBE algorithms otherwise
remain as imported. There are no proprietary firmware images in this new service.
