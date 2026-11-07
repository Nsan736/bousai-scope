#!/usr/bin/env python3
"""AltStoreのソースJSON(apps.json)を生成・更新する。

使い方: make_apps_json.py <apps.json> <version> <ipaのパス> <owner/repo>
既存のapps.jsonがあれば過去のバージョン履歴を引き継ぐ。
"""
import json
import os
import sys
from datetime import datetime, timezone

BUNDLE_ID = "com.nsan.bousaiscope"
APP_NAME = "防災スコープ"
IPA_NAME = "BousaiScope.ipa"
MIN_OS = "17.0"


def main() -> None:
    path, version, ipa, repo = sys.argv[1:5]
    size = os.path.getsize(ipa)
    date = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    url = f"https://github.com/{repo}/releases/download/v{version}/{IPA_NAME}"
    description = "カメラの映像に方角・距離・高さを重ねて、避難場所や浸水の想定などの防災情報を見るアプリ。通信量を少なくする設計。"

    versions = []
    if os.path.exists(path):
        try:
            with open(path, encoding="utf-8") as f:
                old = json.load(f)
            versions = old["apps"][0].get("versions", [])
        except (ValueError, KeyError, IndexError):
            versions = []
    versions = [v for v in versions if v.get("version") != version]
    versions.insert(0, {
        "version": version,
        "date": date,
        "localizedDescription": f"v{version}",
        "downloadURL": url,
        "size": size,
        "minOSVersion": MIN_OS,
    })

    owner = repo.split("/")[0]
    source = {
        "name": f"{APP_NAME} (Nsan736)",
        "identifier": f"{BUNDLE_ID}.source",
        "sourceURL": f"https://raw.githubusercontent.com/{repo}/main/apps.json",
        "apps": [{
            "name": APP_NAME,
            "bundleIdentifier": BUNDLE_ID,
            "developerName": owner,
            "subtitle": "防災情報をカメラで見る",
            "localizedDescription": description,
            "iconURL": f"https://raw.githubusercontent.com/{repo}/main/icon.png",
            "tintColor": "E8740C",
            "screenshotURLs": [],
            "versions": versions,
            "version": version,
            "versionDate": date,
            "versionDescription": f"v{version}",
            "downloadURL": url,
            "size": size,
            "minOSVersion": MIN_OS,
        }],
        "news": [],
    }
    with open(path, "w", encoding="utf-8") as f:
        json.dump(source, f, ensure_ascii=False, indent=2)
        f.write("\n")


if __name__ == "__main__":
    main()
