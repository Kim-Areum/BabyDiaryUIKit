#!/bin/bash
# xcodegen generate 후 실행: SystemCapabilities 주입
cd "$(dirname "$0")/.."
PBXPROJ="BabyDiaryUIKit.xcodeproj/project.pbxproj"

# 이미 추가되어 있으면 스킵
if grep -q "SystemCapabilities" "$PBXPROJ"; then
    echo "✅ SystemCapabilities 이미 존재"
    exit 0
fi

# ProvisioningStyle = Automatic; 다음 줄에 삽입
python3 -c "
import re
with open('$PBXPROJ', 'r') as f:
    content = f.read()

injection = '''						SystemCapabilities = {
							\"com.apple.BackgroundModes\" = {
								enabled = 1;
							};
							\"com.apple.Push\" = {
								enabled = 1;
							};
							\"com.apple.iCloud\" = {
								enabled = 1;
							};
						};'''

content = content.replace(
    'ProvisioningStyle = Automatic;',
    'ProvisioningStyle = Automatic;\n' + injection,
    1
)

with open('$PBXPROJ', 'w') as f:
    f.write(content)
"

echo "✅ SystemCapabilities 주입 완료"
