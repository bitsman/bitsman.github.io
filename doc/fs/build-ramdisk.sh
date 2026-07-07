#!/bin/bash
# build-aarch64-ramdisk-smart.sh - 智能管理busybox源码，避免重复下载

set -e

# 配置
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"  # 获取脚本所在目录
WORK_DIR="aarch64-ramdisk"
BUILD_DIR="$WORK_DIR/build"
ROOTFS_DIR="$WORK_DIR/rootfs"
CROSS_PREFIX="/opt/gcc-linaro-7.3.1-2018.05-x86_64_aarch64-linux-gnu/bin/aarch64-linux-gnu-"
ARCH="arm64"
RAMDISK_IMG="$SCRIPT_DIR/aarch64-ramdisk.cpio.gz"
RAMDISK_UIMG="$SCRIPT_DIR/aarch64-ramdisk.uimg"
MINIMAL_IMG="$SCRIPT_DIR/aarch64-minimal.cpio.gz"
MINIMAL_UIMG="$SCRIPT_DIR/aarch64-minimal.uimg"
BUSYBOX_VERSION="1.36.1"
BUSYBOX_TAR="busybox-$BUSYBOX_VERSION.tar.bz2"
BUSYBOX_URL="https://busybox.net/downloads/$BUSYBOX_TAR"
MKIMAGE_DIR="/home/joe/workbench/hwd10910/repo/u-boot/build/tools"
# 优先从脚本目录查找busybox源码
SCRIPT_BUSYBOX_TAR="$SCRIPT_DIR/$BUSYBOX_TAR"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 显示帮助
show_help() {
    cat << EOF
用法: $0 [选项]

选项:
  build          构建完整的RAM disk文件系统 (默认)
  minimal        构建最小化的RAM disk
  clean          清理所有构建文件
  clean-build    只清理构建文件，保留busybox源码
  get-src        只下载busybox源码到脚本目录
  test           测试RAM disk镜像
  all            构建并测试
  help           显示此帮助信息

特性:
  - 优先从脚本目录($SCRIPT_DIR)获取busybox源码
  - 避免重复下载，支持离线构建
  - 增量编译，智能缓存

Busybox源码管理:
  - 源码包查找顺序:
    1. 脚本所在目录: $SCRIPT_DIR/$BUSYBOX_TAR
    2. 构建目录: $BUILD_DIR/$BUSYBOX_TAR
    3. 从网络下载到脚本目录
  
  - 获取源码: $0 get-src
  - 离线构建: 将busybox-1.36.1.tar.bz2放在脚本目录

示例:
  $0 get-src       # 下载busybox源码到脚本目录
  $0 build         # 构建完整版
  $0 minimal       # 构建最小版
  $0 clean-build   # 清理构建但保留源码
  $0 clean         # 完全清理
  $0 all           # 构建并测试
EOF
}

# 检查busybox是否已编译
check_busybox_built() {
    [ -f "$BUILD_DIR/busybox-$BUSYBOX_VERSION/busybox" ]
}

# 智能下载busybox源码
download_busybox() {
    print_info "检查busybox源码..."
    
    # 检查是否已编译
    if check_busybox_built; then
        print_success "busybox已编译，跳过源码下载"
        return 0
    fi
    
    # 创建构建目录
    mkdir -p "$BUILD_DIR"
    
    # 检查脚本目录是否有源码
    if [ -f "$SCRIPT_BUSYBOX_TAR" ]; then
        print_success "在脚本目录找到busybox源码: $SCRIPT_BUSYBOX_TAR"
        
        # 复制到构建目录
        if [ ! -f "$BUILD_DIR/$BUSYBOX_TAR" ]; then
            print_info "复制源码到构建目录..."
            cp "$SCRIPT_BUSYBOX_TAR" "$BUILD_DIR/"
        fi
    fi
    
    # 检查构建目录是否有源码
    if [ -f "$BUILD_DIR/$BUSYBOX_TAR" ]; then
        print_info "构建目录已有busybox源码，跳过下载"
        
        # 确保已解压
        if [ ! -d "$BUILD_DIR/busybox-$BUSYBOX_VERSION" ]; then
            print_info "解压busybox源码..."
            cd "$BUILD_DIR"
            tar -xjf "$BUSYBOX_TAR"
            cd - >/dev/null
        fi
        return 0
    fi
    
    # 需要下载
    print_info "下载busybox $BUSYBOX_VERSION..."
    
    # 询问下载位置
    echo "下载位置选项:"
    echo "1) 脚本目录 ($SCRIPT_DIR) - 推荐，便于后续复用"
    echo "2) 构建目录 ($BUILD_DIR) - 仅本次构建使用"
    read -p "请选择(1/2, 默认1): " choice
    
    case "${choice:-1}" in
        1)
            DOWNLOAD_DIR="$SCRIPT_DIR"
            ;;
        2)
            DOWNLOAD_DIR="$BUILD_DIR"
            ;;
        *)
            DOWNLOAD_DIR="$SCRIPT_DIR"
            print_warning "无效选择，使用默认: 脚本目录"
            ;;
    esac
    
    # 下载
    print_info "下载到: $DOWNLOAD_DIR"
    cd "$DOWNLOAD_DIR"
    wget --progress=dot:giga "$BUSYBOX_URL"
    
    # 如果下载到脚本目录，也复制到构建目录
    if [ "$DOWNLOAD_DIR" = "$SCRIPT_DIR" ] && [ ! -f "$BUILD_DIR/$BUSYBOX_TAR" ]; then
        print_info "复制源码到构建目录..."
        cp "$BUSYBOX_TAR" "$BUILD_DIR/"
    fi
    
    # 解压
    if [ ! -d "$BUILD_DIR/busybox-$BUSYBOX_VERSION" ]; then
        print_info "解压busybox源码..."
        cd "$BUILD_DIR"
        tar -xjf "$BUSYBOX_TAR"
    fi
    
    cd - >/dev/null
    print_success "busybox源码下载完成"
}

# 只下载busybox源码
download_only() {
    print_info "下载busybox源码到脚本目录..."
    
    if [ -f "$SCRIPT_BUSYBOX_TAR" ]; then
        print_success "脚本目录已有busybox源码: $SCRIPT_BUSYBOX_TAR"
        echo "文件信息:"
        ls -lh "$SCRIPT_BUSYBOX_TAR"
        return 0
    fi
    
    cd "$SCRIPT_DIR"
    print_info "下载busybox $BUSYBOX_VERSION 到: $SCRIPT_DIR"
    wget --progress=dot:giga "$BUSYBOX_URL"
    
    if [ -f "$BUSYBOX_TAR" ]; then
        print_success "busybox源码下载完成"
        echo "文件: $SCRIPT_DIR/$BUSYBOX_TAR"
        echo "大小: $(du -h "$BUSYBOX_TAR" | cut -f1)"
    else
        print_error "下载失败"
    fi
    
    cd - >/dev/null
}

# 智能编译busybox
compile_busybox() {
    print_info "检查busybox编译状态..."

    # 如果已编译，跳过
    if check_busybox_built; then
        print_success "busybox已编译，跳过编译"
        return 0
    fi

    # 确保源码存在
    if [ ! -d "$BUILD_DIR/busybox-$BUSYBOX_VERSION" ]; then
        print_error "busybox源码不存在，尝试下载..."
        download_busybox
    fi

    print_info "交叉编译busybox (aarch64架构)..."
    cd "$BUILD_DIR/busybox-$BUSYBOX_VERSION"

    # 清理并重新配置 (使用allyesconfig避免交互)
    make distclean 2>/dev/null || true
    yes "" | make defconfig

    # 修改配置为静态编译
    sed -i 's/# CONFIG_STATIC is not set/CONFIG_STATIC=y/' .config
    sed -i 's/CONFIG_FEATURE_SHARED_BUSYBOX=y/# CONFIG_FEATURE_SHARED_BUSYBOX is not set/' .config

    # 设置交叉编译工具链
    sed -i "s|^.*CONFIG_CROSS_COMPILER_PREFIX.*$|CONFIG_CROSS_COMPILER_PREFIX=\"$CROSS_PREFIX\"|" .config

    # 编译 (指定ARCH和CROSS_COMPILE)
    make -j$(nproc) ARCH="$ARCH" CROSS_COMPILE="$CROSS_PREFIX"

    cd - >/dev/null
    print_success "busybox编译完成"
}

# 清理构建文件但保留源码
clean_build_only() {
    print_info "清理构建文件 (保留源码)..."
    
    # 卸载并删除挂载点
    if mount | grep -q "$WORK_DIR"; then
        sudo umount "$WORK_DIR"/rootfs/proc 2>/dev/null || true
        sudo umount "$WORK_DIR"/rootfs/sys 2>/dev/null || true
    fi
    
    # 删除根文件系统和镜像，但保留build目录
    rm -rf "$WORK_DIR/rootfs" "$WORK_DIR/minimal-rootfs" 2>/dev/null || true
    rm -f "$RAMDISK_IMG" "$MINIMAL_IMG" 2>/dev/null || true
    
    # 保留build目录中的源码包，只删除解压的目录
    if [ -d "$BUILD_DIR" ]; then
        # 删除解压的目录，保留tar包
        find "$BUILD_DIR" -maxdepth 1 -type d -name "busybox-*" -exec rm -rf {} \; 2>/dev/null || true
    fi
    
    print_success "构建文件已清理 (busybox源码保留)"
}

# 完全清理
clean_all() {
    print_info "完全清理所有文件..."
    
    # 卸载并删除挂载点
    if mount | grep -q "$WORK_DIR"; then
        sudo umount "$WORK_DIR"/rootfs/proc 2>/dev/null || true
        sudo umount "$WORK_DIR"/rootfs/sys 2>/dev/null || true
    fi
    
    # 删除所有构建目录
    rm -rf "$WORK_DIR" "$RAMDISK_IMG" "$MINIMAL_IMG" 2>/dev/null || true
    
    print_success "所有文件已清理"
}

# 检查依赖
check_dependencies() {
    print_info "检查依赖工具..."
    
    # 检查交叉编译工具链
    if ! command -v ${CROSS_PREFIX}gcc >/dev/null 2>&1; then
        print_error "未找到交叉编译工具链: $CROSS_PREFIX"
        echo "请执行以下命令安装:"
        echo "  Ubuntu/Debian: sudo apt-get install gcc-aarch64-linux-gnu"
        return 1
    fi
    
    # 检查必要工具
    for tool in wget tar make; do
        if ! command -v $tool >/dev/null 2>&1; then
            print_error "未找到工具: $tool"
            echo "安装依赖: sudo apt-get install wget tar make genext2fs e2fsprogs"
            return 1
        fi
    done
    
    print_success "所有依赖已满足"
    return 0
}

# 创建根文件系统
create_rootfs() {
    print_info "创建根文件系统..."

    # 清理旧的根文件系统
    rm -rf "$ROOTFS_DIR"
    mkdir -p "$ROOTFS_DIR"

    # 获取busybox二进制路径
    local BUSYBOX_BIN="$BUILD_DIR/busybox-$BUSYBOX_VERSION/busybox"

    # 创建目录结构
    mkdir -p "$ROOTFS_DIR"/{bin,dev,etc,proc,root,sys,tmp}
    mkdir -p "$ROOTFS_DIR"/dev/pts
    mkdir -p "$ROOTFS_DIR"/usr/{bin,sbin}
    mkdir -p "$ROOTFS_DIR"/sbin

    # 设置权限
    chmod 1777 "$ROOTFS_DIR/tmp"

    # 复制busybox
    cp "$BUSYBOX_BIN" "$ROOTFS_DIR/bin/"

    # 创建设备节点 (使用busybox的mknod)
    if "$BUSYBOX_BIN" mknod -m 622 "$ROOTFS_DIR/dev/console" c 5 1 2>/dev/null; then
        print_info "创建console设备节点"
    else
        sudo "$BUSYBOX_BIN" mknod -m 622 "$ROOTFS_DIR/dev/console" c 5 1 2>/dev/null ||
        print_warning "无法创建console设备节点，将在init中创建"
    fi

    # 创建null设备
    "$BUSYBOX_BIN" mknod -m 666 "$ROOTFS_DIR/dev/null" c 1 3 2>/dev/null ||
    sudo "$BUSYBOX_BIN" mknod -m 666 "$ROOTFS_DIR/dev/null" c 1 3 2>/dev/null || true

    # 创建tty设备
    "$BUSYBOX_BIN" mknod -m 666 "$ROOTFS_DIR/dev/tty" c 5 0 2>/dev/null ||
    sudo "$BUSYBOX_BIN" mknod -m 666 "$ROOTFS_DIR/dev/tty" c 5 0 2>/dev/null || true

    # 创建控制台终端
    "$BUSYBOX_BIN" ln -sf /dev/console "$ROOTFS_DIR/dev/tty1" 2>/dev/null || true

    # 创建一些busybox命令的符号链接
    for cmd in sh mount ls cat echo ps; do
        "$BUSYBOX_BIN" ln -sf /bin/busybox "$ROOTFS_DIR/bin/$cmd" 2>/dev/null || true
    done

    # 创建init脚本
    cat > "$ROOTFS_DIR/init" << 'EOF'
#!/bin/busybox sh

# 挂载基本文件系统
/bin/busybox mount -t proc proc /proc
/bin/busybox mount -t sysfs sysfs /sys
/bin/busybox mount -t devtmpfs devtmpfs /dev
/bin/busybox mount -t tmpfs tmpfs /tmp
/bin/busybox mkdir -p /dev/pts
/bin/busybox mount -t devpts devpts /dev/pts

# 设置主机名
/bin/busybox hostname aarch64-ramdisk

# 创建必要的符号链接
for cmd in sh mount ls cat echo ps hostname mkdir mknod ln chmod dmesg grep sleep; do
    /bin/busybox ln -sf /bin/busybox /bin/$cmd 2>/dev/null
done

# 确保必要的设备节点存在
if [ ! -c /dev/console ]; then
    /bin/busybox mknod -m 622 /dev/console c 5 1
fi
if [ ! -c /dev/null ]; then
    /bin/busybox mknod -m 666 /dev/null c 1 3
fi
if [ ! -c /dev/tty ]; then
    /bin/busybox mknod -m 666 /dev/tty c 5 0
fi
if [ ! -c /dev/zero ]; then
    /bin/busybox mknod -m 666 /dev/zero c 1 5
fi

# 创建一些虚拟终端设备
for i in 0 1 2 3; do
    if [ ! -c /dev/tty$i ]; then
        /bin/busybox mknod -m 620 /dev/tty$i c 4 $i
    fi
done

# 显示欢迎信息
echo "========================================"
echo "  aarch64 RAM disk 系统已启动"
echo "  架构: aarch64"
echo "========================================"

# 设置环境
export TERM=linux
export PATH=/bin:/sbin:/usr/bin:/usr/sbin

# 重定向到控制台
exec 0</dev/console
exec 1>/dev/console
exec 2>&1

# 使用setsid和cttyhack获取job control
if /bin/busybox --list | grep -q cttyhack; then
    exec /bin/busybox setsid /bin/busybox cttyhack /bin/sh
else
    exec /bin/sh
fi
EOF
    chmod +x "$ROOTFS_DIR/init"

    print_success "根文件系统创建完成"
}

# 创建最小根文件系统
create_minimal_rootfs() {
    print_info "创建最小根文件系统..."
    
    local minimal_rootfs="$WORK_DIR/minimal-rootfs"
    rm -rf "$minimal_rootfs"
    mkdir -p "$minimal_rootfs"
    
    # 获取busybox二进制路径
    local BUSYBOX_BIN="$BUILD_DIR/busybox-$BUSYBOX_VERSION/busybox"
    
    # 创建最简目录结构
    mkdir -p "$minimal_rootfs"/{bin,dev,proc,sys,tmp,root,etc}
    mkdir -p "$minimal_rootfs"/dev/pts  # 确保dev/pts目录存在
    
    # 设置/tmp目录权限
    chmod 1777 "$minimal_rootfs/tmp"
    
    # 复制busybox
    cp "$BUSYBOX_BIN" "$minimal_rootfs/bin/"
    
    # === 关键修改1：使用busybox的mknod创建必要的设备节点 ===
    # 只创建最基础的节点，其他由devtmpfs或init脚本处理
    if "$BUSYBOX_BIN" mknod -m 622 "$minimal_rootfs/dev/console" c 5 1 2>/dev/null; then
        print_info "创建console设备节点"
    else
        # 尝试sudo
        sudo "$BUSYBOX_BIN" mknod -m 622 "$minimal_rootfs/dev/console" c 5 1 2>/dev/null || 
        print_warning "无法创建console设备节点，将在init中创建"
    fi
    
    # 创建null设备
    "$BUSYBOX_BIN" mknod -m 666 "$minimal_rootfs/dev/null" c 1 3 2>/dev/null ||
    sudo "$BUSYBOX_BIN" mknod -m 666 "$minimal_rootfs/dev/null" c 1 3 2>/dev/null || true
    
    # === 关键修改2：简化符号链接 ===
    # 创建控制台终端
    "$BUSYBOX_BIN" ln -sf /dev/console "$minimal_rootfs/dev/tty1" 2>/dev/null || true
    
    # 创建一些busybox命令的符号链接（最小集）
    for cmd in sh mount ls cat echo ps; do
        "$BUSYBOX_BIN" ln -sf /bin/busybox "$minimal_rootfs/bin/$cmd" 2>/dev/null || true
    done

    # 创建最简单的init脚本
    cat > "$minimal_rootfs/init" << 'EOF'
#!/bin/busybox sh

# 挂载基本文件系统
/bin/busybox mount -t proc proc /proc
/bin/busybox mount -t sysfs sysfs /sys
/bin/busybox mount -t devtmpfs devtmpfs /dev
/bin/busybox mount -t tmpfs tmpfs /tmp
/bin/busybox mkdir -p /dev/pts
/bin/busybox mount -t devpts devpts /dev/pts

# 设置主机名
/bin/busybox hostname minimal-aarch64

# 创建所有busybox命令的符号链接
# 这是关键：确保mknod等命令可用
#for applet in $(/bin/busybox --list)
#do
#    /bin/busybox ln -sf /bin/busybox /bin/$applet 2>/dev/null
#done
# 只创建最必要的符号链接
for cmd in sh mount ls cat echo ps hostname mkdir mknod ln chmod dmesg grep sleep; do
    /bin/busybox ln -sf /bin/busybox /bin/$cmd 2>/dev/null
done

# 确保必要的设备节点存在
if [ ! -c /dev/console ]; then
    /bin/busybox mknod -m 622 /dev/console c 5 1
fi
if [ ! -c /dev/null ]; then
    /bin/busybox mknod -m 666 /dev/null c 1 3
fi
if [ ! -c /dev/tty ]; then
    /bin/busybox mknod -m 666 /dev/tty c 5 0
fi
if [ ! -c /dev/zero ]; then
    /bin/busybox mknod -m 666 /dev/zero c 1 5
fi

# 创建一些虚拟终端设备
for i in 0 1 2 3; do
    if [ ! -c /dev/tty$i ]; then
        /bin/busybox mknod -m 620 /dev/tty$i c 4 $i
    fi
done

echo "========================================"
echo "  最小aarch64 RAM disk已启动"
echo "========================================"

# 设置环境
export TERM=linux
export PATH=/bin:/sbin:/usr/bin:/usr/sbin

# 重定向到控制台
exec 0</dev/console
exec 1>/dev/console
exec 2>&1

# 使用setsid和cttyhack获取job control
# 注意：需要确保busybox编译时包含CTTYHACK和SETSID
if /bin/busybox --list | grep -q cttyhack; then
    exec /bin/busybox setsid /bin/busybox cttyhack /bin/sh
else
    # 回退方案
    exec /bin/sh
fi
EOF

    chmod +x "$minimal_rootfs/init"
    
    print_success "最小根文件系统创建完成"
}

# 创建initramfs cpio.gz归档
create_initramfs() {
    local rootfs_dir="$1"
    local output_cpio="$2"
    local cur_dir=$(pwd)

    print_info "创建initramfs: $output_cpio"

    cd "$rootfs_dir"
    find . | cpio -o -H newc | gzip > "$output_cpio"
    cd "$cur_dir"

    local final_size=$(du -h "$output_cpio" | cut -f1)
    print_success "initramfs创建完成: $output_cpio (${final_size})"
}

# 构建完整版
build_full() {
    print_info "开始构建完整版aarch64 RAM disk..."
    
    # 检查依赖
    if ! check_dependencies; then
        return 1
    fi
    
    # 清理旧的构建文件
    clean_build_only
    
    # 下载和编译busybox
    download_busybox
    compile_busybox
    
    # 创建根文件系统
    create_rootfs
    
    # 创建initramfs
    create_initramfs "$ROOTFS_DIR" "$RAMDISK_IMG"

    # 使用mkimage打包
    print_info "打包为uImage: $RAMDISK_UIMG"
    "$MKIMAGE_DIR/mkimage" -A arm64 -O linux -T ramdisk -C gzip \
        -n "HWD10910 Initramfs" \
        -d "$RAMDISK_IMG" "$RAMDISK_UIMG"

    print_success "完整版构建完成!"
    print_info "镜像文件: $RAMDISK_UIMG"
    print_info "大小: $(du -h "$RAMDISK_UIMG" | cut -f1)"
    print_info "大小: $(du -h "$RAMDISK_IMG" | cut -f1)"
    echo ""
    print_info "Busybox源码位置: $SCRIPT_DIR/$BUSYBOX_TAR"
    print_info "下次构建将复用此源码，无需重新下载"
}

# 构建最小版
build_minimal() {
    print_info "开始构建最小版aarch64 RAM disk..."
    
    # 检查依赖
    if ! check_dependencies; then
        return 1
    fi
    
    # 清理旧的构建文件
    clean_build_only
    
    # 下载和编译busybox
    download_busybox
    compile_busybox
    
    # 创建最小根文件系统
    create_minimal_rootfs
    
    # 创建initramfs
    create_initramfs "$WORK_DIR/minimal-rootfs" "$MINIMAL_IMG"

    # 使用mkimage打包
    print_info "打包为uImage: $MINIMAL_UIMG"
    "$MKIMAGE_DIR/mkimage" -A arm64 -O linux -T ramdisk -C gzip \
        -n "HWD10910 Initramfs" \
        -d "$MINIMAL_IMG" "$MINIMAL_UIMG"

    print_success "最小版构建完成!"
    print_info "镜像文件: $MINIMAL_UIMG"
    print_info "大小: $(du -h "$MINIMAL_UIMG" | cut -f1)"
    echo ""
    print_info "Busybox源码位置: $SCRIPT_DIR/$BUSYBOX_TAR"
    print_info "下次构建将复用此源码，无需重新下载"
}

# 测试镜像
test_image() {
    print_info "测试RAM disk镜像..."
    
    # 检查QEMU
    if ! command -v qemu-system-aarch64 >/dev/null 2>&1; then
        print_error "未找到qemu-system-aarch64"
        echo "安装: sudo apt-get install qemu-system-arm"
        return 1
    fi
    
    # 选择要测试的镜像
    local test_img
    if [ -f "$RAMDISK_IMG" ]; then
        test_img="$RAMDISK_IMG"
    elif [ -f "$MINIMAL_IMG" ]; then
        test_img="$MINIMAL_IMG"
    else
        print_error "未找到RAM disk镜像，请先构建"
        return 1
    fi
    
    print_info "启动QEMU测试 (按Ctrl+A, 然后X退出)..."
    echo
    
    # 使用QEMU的内置内核
    qemu-system-aarch64 \
        -M virt \
        -cpu cortex-a57 \
        -smp 1 \
        -m 256M \
        -initrd "$test_img" \
        -nographic \
        -append "console=ttyAMA0 init=/init" \
        -no-reboot
}

# 显示状态
show_status() {
    echo "=== 构建系统状态 ==="
    echo "脚本目录: $SCRIPT_DIR"
    echo "工作目录: $(pwd)/$WORK_DIR"
    echo ""
    
    # 检查busybox源码
    if [ -f "$SCRIPT_BUSYBOX_TAR" ]; then
        echo "✓ Busybox源码: $SCRIPT_BUSYBOX_TAR"
        echo "  大小: $(du -h "$SCRIPT_BUSYBOX_TAR" 2>/dev/null | cut -f1 || echo "未知")"
    else
        echo "✗ Busybox源码: 未找到 (运行 '$0 get-src' 下载)"
    fi
    
    # 检查构建状态
    if [ -f "$RAMDISK_UIMG" ]; then
        echo "✓ 完整镜像: $RAMDISK_UIMG"
        echo "  大小: $(du -h "$RAMDISK_UIMG" 2>/dev/null | cut -f1)"
    fi

    if [ -f "$MINIMAL_UIMG" ]; then
        echo "✓ 最小镜像: $MINIMAL_UIMG"
        echo "  大小: $(du -h "$MINIMAL_UIMG" 2>/dev/null | cut -f1)"
    fi
    
    # 检查工具链
    if command -v ${CROSS_PREFIX}gcc >/dev/null 2>&1; then
        echo "✓ 交叉编译工具链: 已安装 ($CROSS_PREFIX)"
    else
        echo "✗ 交叉编译工具链: 未安装"
    fi
    
    echo ""
}

# 主函数
main() {
    # 显示脚本信息
    echo "=== aarch64 RAM disk构建脚本 ==="
    echo "脚本位置: $SCRIPT_DIR"
    echo "当前目录: $(pwd)"
    echo ""
    
    case "${1:-help}" in
        build|full)
            build_full
            ;;
        minimal)
            build_minimal
            ;;
        get-src|download)
            download_only
            ;;
        clean-build)
            clean_build_only
            ;;
        clean)
            clean_all
            ;;
        test)
            test_image
            ;;
        status)
            show_status
            ;;
        all)
            build_full
            echo
            read -p "构建完成，是否测试? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                test_image
            fi
            ;;
        help|-h|--help)
            show_help
            ;;
        *)
            print_error "未知选项: $1"
            show_help
            exit 1
            ;;
    esac
}

# 运行主函数
main "$@"
