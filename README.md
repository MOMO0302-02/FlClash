<div>

[**简体中文**](README_zh_CN.md)

</div>

## ClashMO

[![License](https://img.shields.io/github/license/MOMO0302-02/ClashMO?style=flat-square)](LICENSE)

A multi-platform proxy client based on ClashMeta, simple and easy to use, open-source and ad-free.

ClashMO is a fork of [chen08209/FlClash](https://github.com/chen08209/FlClash). All credit for the original work goes to its authors. The mobile interface follows the concepts of [Clash Party](https://github.com/mihomo-party-org/clash-party) and includes Smart routing.

on Desktop:
<p style="text-align: center;">
    <img alt="desktop" src="snapshots/desktop.gif">
</p>

on Mobile:
<p style="text-align: center;">
    <img alt="mobile" src="snapshots/mobile.gif">
</p>

## Features

✈️ Multi-platform: Android, Windows, macOS and Linux

💻 Adaptive multiple screen sizes, Multiple color themes available

💡 Clash Party-style dashboard with Smart routing

☁️ Supports data sync via WebDAV

✨ Support subscription link, Dark mode

## Use

### Linux

⚠️ Make sure to install the following dependencies before using them

   ```bash
    sudo apt-get install libayatana-appindicator3-dev
    sudo apt-get install libkeybinder-3.0-dev
   ```

### Android

Support the following actions

   ```bash
    com.clashparty.app.action.START
    
    com.clashparty.app.action.STOP
    
    com.clashparty.app.action.TOGGLE
   ```

## Download

Grab the latest build from [Releases](https://github.com/MOMO0302-02/ClashMO/releases).

## Build

1. Update submodules
   ```bash
   git submodule update --init --recursive
   ```

2. Install `Flutter` and `Golang` environment

3. Build Application

    - android

        1. Install `Android SDK`, `Android NDK`

        2. Set `ANDROID_NDK` environment variable

        3. Run build script

           ```bash
           dart setup.dart android
           ```

    - windows

        1. Requires a Windows client

        2. Install `GCC`, `Inno Setup`

        3. Run build script

           ```bash
           dart setup.dart windows
           ```

    - linux

        1. Requires a Linux client

        2. Dependencies are auto-installed by setup script, or manually:
           ```bash
           sudo apt-get install -y libayatana-appindicator3-dev libkeybinder-3.0-dev
           ```

        3. Run build script

           ```bash
           dart setup.dart linux
           ```

    - macOS

        1. Requires a macOS client

        2. Run build script

           ```bash
           dart setup.dart macos
           ```

## Star

The easiest way to support developers is to click on the star (⭐) at the top of the page.
