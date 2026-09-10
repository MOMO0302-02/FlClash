<div>

[**English**](README.md)

</div>

## ClashMO

[![License](https://img.shields.io/github/license/MOMO0302-02/ClashMO?style=flat-square)](LICENSE)

基于 ClashMeta 的多平台代理客户端，简单易用，开源无广告。

ClashMO 是 [chen08209/FlClash](https://github.com/chen08209/FlClash) 的分支，原项目版权归其作者所有。手机界面参考了 [Clash Party](https://github.com/mihomo-party-org/clash-party) 的操作方式，并包含 Smart 智能选路。

on Desktop:
<p style="text-align: center;">
    <img alt="desktop" src="snapshots/desktop.gif">
</p>

on Mobile:
<p style="text-align: center;">
    <img alt="mobile" src="snapshots/mobile.gif">
</p>

## Features

✈️ 多平台: Android, Windows, macOS and Linux

💻 自适应多个屏幕尺寸,多种颜色主题可供选择

💡 Clash Party 风格的首页，带 Smart 智能选路

☁️ 支持通过WebDAV同步数据

✨ 支持一键导入订阅, 深色模式

## Use

### Linux

⚠️ 使用前请确保安装以下依赖

   ```bash
    sudo apt-get install libayatana-appindicator3-dev
    sudo apt-get install libkeybinder-3.0-dev
   ```

### Android

支持下列操作

   ```bash
    com.clashparty.app.action.START
    
    com.clashparty.app.action.STOP
    
    com.clashparty.app.action.TOGGLE
   ```

## Download

到 [Releases](https://github.com/MOMO0302-02/ClashMO/releases) 下载最新版本。

## Build

1. 更新 submodules
   ```bash
   git submodule update --init --recursive
   ```

2. 安装 `Flutter` 以及 `Golang` 环境

3. 构建应用

    - android

        1. 安装  `Android SDK` ,  `Android NDK`

        2. 设置 `ANDROID_NDK` 环境变量

        3. 运行构建脚本

           ```bash
           dart setup.dart android
           ```

    - windows

        1. 你需要一个windows客户端

        2. 安装 `GCC`，`Inno Setup`

        3. 运行构建脚本

           ```bash
           dart setup.dart windows
           ```

    - linux

        1. 你需要一个linux客户端

        2. 依赖会由 setup 脚本自动安装，也可以手动安装：
           ```bash
           sudo apt-get install -y libayatana-appindicator3-dev libkeybinder-3.0-dev
           ```

        3. 运行构建脚本

           ```bash
           dart setup.dart linux
           ```

    - macOS

        1. 你需要一个macOS客户端

        2. 运行构建脚本

           ```bash
           dart setup.dart macos
           ```

## Star

支持开发者的最简单方式是点击页面顶部的星标（⭐）。
