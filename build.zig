const std = @import("std");

const DeepfreezeStep = struct {
    step: std.Build.Step,
    modules: std.StringHashMapUnmanaged(std.Build.LazyPath),
    deepfreeze_program: std.Build.LazyPath,
    output_file: std.Build.GeneratedFile,

    pub fn create(b: *std.Build, deepfreezeProgram: std.Build.LazyPath) *DeepfreezeStep {
        const self = b.allocator.create(DeepfreezeStep) catch @panic("OOM");
        self.* = .{
            .step = std.Build.Step.init(.{
                .id = .custom,
                .name = "Generate deepfreeze.c",
                .owner = b,
                .makeFn = make,
            }),
            .deepfreeze_program = deepfreezeProgram,
            .modules = .{},
            .output_file = .{ .step = &self.step },
        };

        deepfreezeProgram.addStepDependencies(&self.step);
        return self;
    }

    pub fn addModule(self: *DeepfreezeStep, source: std.Build.LazyPath, name: []const u8) void {
        const b = self.step.owner;
        self.modules.put(b.allocator, name, source) catch @panic("OOM");
    }

    fn make(step: *std.Build.Step, _: *std.Progress.Node) anyerror!void {
        const b = step.owner;
        const self = @fieldParentPtr(DeepfreezeStep, "step", step);

        var man = b.graph.cache.obtain();
        defer man.deinit();

        const cmd = try b.findProgram(&.{ "python3", "python" }, &.{});

        _ = try man.addFile(self.deepfreeze_program.getPath2(b, step), null);

        {
            var iter = self.modules.iterator();
            while (iter.next()) |module| {
                _ = try man.addFile(module.value_ptr.getPath2(b, step), null);
            }
        }

        if (try step.cacheHit(&man)) {
            const digest = man.final();
            self.output_file.path = try b.cache_root.join(b.allocator, &.{ "o", &digest, "deepfreeze.c" });
            return;
        }

        const digest = man.final();
        const cache_path = "o" ++ std.fs.path.sep_str ++ digest;

        var cache_dir = b.cache_root.handle.makeOpenPath(cache_path, .{}) catch |err| {
            return step.fail("unable to make path  = 1,{}{s} = 1,: {s}", .{
                b.cache_root, cache_path, @errorName(err),
            });
        };
        defer cache_dir.close();
        self.output_file.path = try b.cache_root.join(b.allocator, &.{ "o", &digest, "deepfreeze.c" });

        var args = std.ArrayList([]const u8).init(b.allocator);
        defer args.deinit();

        try args.appendSlice(&.{
            cmd,
            self.deepfreeze_program.getPath2(b, step),
        });

        {
            var iter = self.modules.iterator();
            while (iter.next()) |module| {
                try args.append(b.fmt("{s}:{s}", .{ module.value_ptr.getPath2(b, step), module.key_ptr.* }));
            }
        }

        try args.appendSlice(&.{
            "-o",
            self.output_file.path.?,
        });

        try step.evalChildProcess(try args.toOwnedSlice());
        try step.writeManifest(&man);
    }
};

fn addObjsOmitFrozen(cs: *std.Build.Step.Compile, source: *std.Build.Dependency) void {
    const b = cs.step.owner;

    cs.addCSourceFiles(.{
        .files = &.{
            source.path("Modules/getbuildinfo.c").getPath(b),
            source.path("Parser/token.c").getPath(b),
            source.path("Parser/pegen.c").getPath(b),
            source.path("Parser/pegen_errors.c").getPath(b),
            source.path("Parser/action_helpers.c").getPath(b),
            source.path("Parser/parser.c").getPath(b),
            source.path("Parser/string_parser.c").getPath(b),
            source.path("Parser/peg_api.c").getPath(b),
            source.path("Parser/myreadline.c").getPath(b),
            source.path("Parser/tokenizer.c").getPath(b),
            source.path("Objects/abstract.c").getPath(b),
            source.path("Objects/boolobject.c").getPath(b),
            source.path("Objects/bytes_methods.c").getPath(b),
            source.path("Objects/bytearrayobject.c").getPath(b),
            source.path("Objects/bytesobject.c").getPath(b),
            source.path("Objects/call.c").getPath(b),
            source.path("Objects/capsule.c").getPath(b),
            source.path("Objects/cellobject.c").getPath(b),
            source.path("Objects/classobject.c").getPath(b),
            source.path("Objects/codeobject.c").getPath(b),
            source.path("Objects/complexobject.c").getPath(b),
            source.path("Objects/descrobject.c").getPath(b),
            source.path("Objects/enumobject.c").getPath(b),
            source.path("Objects/exceptions.c").getPath(b),
            source.path("Objects/genericaliasobject.c").getPath(b),
            source.path("Objects/genobject.c").getPath(b),
            source.path("Objects/fileobject.c").getPath(b),
            source.path("Objects/floatobject.c").getPath(b),
            source.path("Objects/frameobject.c").getPath(b),
            source.path("Objects/funcobject.c").getPath(b),
            source.path("Objects/interpreteridobject.c").getPath(b),
            source.path("Objects/iterobject.c").getPath(b),
            source.path("Objects/listobject.c").getPath(b),
            source.path("Objects/longobject.c").getPath(b),
            source.path("Objects/dictobject.c").getPath(b),
            source.path("Objects/odictobject.c").getPath(b),
            source.path("Objects/memoryobject.c").getPath(b),
            source.path("Objects/methodobject.c").getPath(b),
            source.path("Objects/moduleobject.c").getPath(b),
            source.path("Objects/namespaceobject.c").getPath(b),
            source.path("Objects/object.c").getPath(b),
            source.path("Objects/obmalloc.c").getPath(b),
            source.path("Objects/picklebufobject.c").getPath(b),
            source.path("Objects/rangeobject.c").getPath(b),
            source.path("Objects/setobject.c").getPath(b),
            source.path("Objects/sliceobject.c").getPath(b),
            source.path("Objects/structseq.c").getPath(b),
            source.path("Objects/tupleobject.c").getPath(b),
            source.path("Objects/typeobject.c").getPath(b),
            source.path("Objects/typevarobject.c").getPath(b),
            source.path("Objects/unicodeobject.c").getPath(b),
            source.path("Objects/unicodectype.c").getPath(b),
            source.path("Objects/unionobject.c").getPath(b),
            source.path("Objects/weakrefobject.c").getPath(b),
            source.path("Python/_warnings.c").getPath(b),
            source.path("Python/Python-ast.c").getPath(b),
            source.path("Python/Python-tokenize.c").getPath(b),
            source.path("Python/asdl.c").getPath(b),
            source.path("Python/assemble.c").getPath(b),
            source.path("Python/ast.c").getPath(b),
            source.path("Python/ast_opt.c").getPath(b),
            source.path("Python/ast_unparse.c").getPath(b),
            source.path("Python/bltinmodule.c").getPath(b),
            source.path("Python/ceval.c").getPath(b),
            source.path("Python/codecs.c").getPath(b),
            source.path("Python/compile.c").getPath(b),
            source.path("Python/context.c").getPath(b),
            source.path("Python/dynamic_annotations.c").getPath(b),
            source.path("Python/errors.c").getPath(b),
            source.path("Python/flowgraph.c").getPath(b),
            source.path("Python/frame.c").getPath(b),
            source.path("Python/frozenmain.c").getPath(b),
            source.path("Python/future.c").getPath(b),
            source.path("Python/getargs.c").getPath(b),
            source.path("Python/getcompiler.c").getPath(b),
            source.path("Python/getcopyright.c").getPath(b),
            source.path("Python/getplatform.c").getPath(b),
            source.path("Python/getversion.c").getPath(b),
            source.path("Python/ceval_gil.c").getPath(b),
            source.path("Python/hamt.c").getPath(b),
            source.path("Python/hashtable.c").getPath(b),
            source.path("Python/import.c").getPath(b),
            source.path("Python/importdl.c").getPath(b),
            source.path("Python/initconfig.c").getPath(b),
            source.path("Python/instrumentation.c").getPath(b),
            source.path("Python/intrinsics.c").getPath(b),
            source.path("Python/legacy_tracing.c").getPath(b),
            source.path("Python/marshal.c").getPath(b),
            source.path("Python/modsupport.c").getPath(b),
            source.path("Python/mysnprintf.c").getPath(b),
            source.path("Python/mystrtoul.c").getPath(b),
            source.path("Python/pathconfig.c").getPath(b),
            source.path("Python/preconfig.c").getPath(b),
            source.path("Python/pyarena.c").getPath(b),
            source.path("Python/pyctype.c").getPath(b),
            source.path("Python/pyfpe.c").getPath(b),
            source.path("Python/pyhash.c").getPath(b),
            source.path("Python/pylifecycle.c").getPath(b),
            source.path("Python/pymath.c").getPath(b),
            source.path("Python/pystate.c").getPath(b),
            source.path("Python/pythonrun.c").getPath(b),
            source.path("Python/pytime.c").getPath(b),
            source.path("Python/bootstrap_hash.c").getPath(b),
            source.path("Python/specialize.c").getPath(b),
            source.path("Python/structmember.c").getPath(b),
            source.path("Python/symtable.c").getPath(b),
            source.path("Python/sysmodule.c").getPath(b),
            source.path("Python/thread.c").getPath(b),
            source.path("Python/traceback.c").getPath(b),
            source.path("Python/tracemalloc.c").getPath(b),
            source.path("Python/getopt.c").getPath(b),
            source.path("Python/pystrcmp.c").getPath(b),
            source.path("Python/pystrtod.c").getPath(b),
            source.path("Python/pystrhex.c").getPath(b),
            source.path("Python/dtoa.c").getPath(b),
            source.path("Python/formatter_unicode.c").getPath(b),
            source.path("Python/fileutils.c").getPath(b),
            source.path("Python/suggestions.c").getPath(b),
            source.path("Python/perf_trampoline.c").getPath(b),
            source.path("Python/dynload_shlib.c").getPath(b),
            source.path("Modules/main.c").getPath(b),
            source.path("Modules/gcmodule.c").getPath(b),
        },
    });
}

fn addFrozenModule(cs: *std.Build.Step.Compile, source: std.Build.LazyPath, name: []const u8) std.Build.LazyPath {
    const b = cs.step.owner;
    const run = b.addRunArtifact(cs);

    run.addFileArg(source);
    return run.addOutputFileArg(name);
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const linkage = b.option(std.Build.Step.Compile.Linkage, "linkage", "whether to statically or dynamically link the library") orelse .static;

    const source = b.dependency("python", .{});

    const modulesConfig = b.addConfigHeader(.{
        .style = .{
            .autoconf = source.path("Modules/config.c.in"),
        },
        .include_path = "config.c",
    }, .{});

    const pyconfigHeader = b.addConfigHeader(.{
        .style = .{
            .autoconf = source.path("pyconfig.h.in"),
        },
        .include_path = "pyconfig.h",
    }, .{
        .AC_APPLE_UNIVERSAL_BUILD = null,
        .AIX_BUILDDATE = null,
        .AIX_GENUINE_CPLUSPLUS = null,
        .ALIGNOF_LONG = target.result.c_type_alignment(.long),
        .ALIGNOF_MAX_ALIGN_T = target.result.maxIntAlignment(),
        .ALIGNOF_SIZE_T = target.result.maxIntAlignment(),
        .ALT_SOABI = null,
        .ANDROID_API_LEVEL = null,
        .DOUBLE_IS_ARM_MIXED_ENDIAN_IEEE754 = 0,
        .DOUBLE_IS_BIG_ENDIAN_IEEE754 = 0,
        .DOUBLE_IS_LITTLE_ENDIAN_IEEE754 = 0,
        .ENABLE_IPV6 = true,
        .FLOAT_WORDS_BIGENDIAN = 0,
        .GETPGRP_HAVE_ARG = 1,
        .HAVE_ACCEPT = 1,
        .HAVE_ACCEPT4 = 1,
        .HAVE_ACOSH = 1,
        .HAVE_ADDRINFO = 1,
        .HAVE_ALARM = 1,
        .HAVE_ALIGNED_REQUIRED = 1,
        .HAVE_ALLOCA_H = @intFromBool(target.result.isGnuLibC()),
        .HAVE_ALTZONE = null,
        .HAVE_ASINH = 1,
        .HAVE_ASM_TYPES_H = 1,
        .HAVE_ATANH = 1,
        .HAVE_BIND = 1,
        .HAVE_BIND_TEXTDOMAIN_CODESET = 0,
        .HAVE_BLUETOOTH_BLUETOOTH_H = 0,
        .HAVE_BLUETOOTH_H = 0,
        .HAVE_BROKEN_POLL = 0,
        .HAVE_BROKEN_MBSTOWCS = 0,
        .HAVE_BROKEN_NICE = 0,
        .HAVE_BROKEN_PIPE_BUF = 0,
        .HAVE_BROKEN_PTHREAD_SIGMASK = 0,
        .HAVE_BROKEN_POSIX_SEMAPHORES = 0,
        .HAVE_BROKEN_SEM_GETVALUE = 0,
        .HAVE_BROKEN_UNSETENV = 0,
        .HAVE_BUILTIN_ATOMIC = 1,
        .HAVE_BZLIB_H = 0,
        .HAVE_CHFLAGS = 1,
        .HAVE_CHMOD = 1,
        .HAVE_CHOWN = 1,
        .HAVE_CHROOT = 1,
        .HAVE_CLOCK = 1,
        .HAVE_CLOCK_GETRES = 1,
        .HAVE_CLOCK_GETTIME = 1,
        .HAVE_CLOCK_NANOSLEEP = 1,
        .HAVE_CLOCK_SETTIME = 1,
        .HAVE_CLOSE_RANGE = 1,
        .HAVE_COMPUTED_GOTOS = 0,
        .HAVE_CONFSTR = 0,
        .HAVE_CONIO_H = 0,
        .HAVE_CONNECT = 1,
        .HAVE_COPY_FILE_RANGE = 0,
        .HAVE_CRYPT_H = 0,
        .HAVE_CRYPT_R = 0,
        .HAVE_CTERMID = 0,
        .HAVE_CTERMID_R = 0,
        .HAVE_CURSES_FILTER = 0,
        .HAVE_CURSES_H = 0,
        .HAVE_CURSES_HAS_KEY = 0,
        .HAVE_CURSES_IMMEDOK = 0,
        .HAVE_CURSES_IS_PAD = 0,
        .HAVE_CURSES_IS_TERM_RESIZED = 0,
        .HAVE_CURSES_RESIZETERM = 0,
        .HAVE_CURSES_RESIZE_TERM = 0,
        .HAVE_CURSES_SYNCOK = 0,
        .HAVE_CURSES_TYPEAHEAD = 0,
        .HAVE_CURSES_USE_ENV = 0,
        .HAVE_CURSES_WCHGAT = 0,
        .HAVE_DB_H = 0,
        .HAVE_DECL_RTLD_DEEPBIND = 0,
        .HAVE_DECL_RTLD_GLOBAL = 0,
        .HAVE_DECL_RTLD_LAZY = 0,
        .HAVE_DECL_RTLD_LOCAL = 0,
        .HAVE_DECL_RTLD_MEMBER = 0,
        .HAVE_DECL_RTLD_NODELETE = 0,
        .HAVE_DECL_RTLD_NOLOAD = 0,
        .HAVE_DECL_RTLD_NOW = 0,
        .HAVE_DECL_TZNAME = 0,
        .HAVE_DEVICE_MACROS = 1,
        .HAVE_DEV_PTC = 1,
        .HAVE_DEV_PTMX = 1,
        .HAVE_DIRECT_H = 1,
        .HAVE_DIRENT_D_TYPE = 1,
        .HAVE_DIRENT_H = 1,
        .HAVE_DIRFD = 1,
        .HAVE_DLFCN_H = 1,
        .HAVE_DLOPEN = 1,
        .HAVE_DUP = 1,
        .HAVE_DUP2 = 1,
        .HAVE_DUP3 = 1,
        .HAVE_DYLD_SHARED_CACHE_CONTAINS_PATH = null,
        .HAVE_DYNAMIC_LOADING = @as(?u8, if (linkage == .dynamic) 1 else null),
        .HAVE_EDITLINE_READLINE_H = 0,
        .HAVE_ENDIAN_H = 0,
        .HAVE_EPOLL = 1,
        .HAVE_EPOLL_CREATE1 = 1,
        .HAVE_ERF = null,
        .HAVE_ERFC = null,
        .HAVE_ERRNO_H = 1,
        .HAVE_EVENTFD = 1,
        .HAVE_EXECV = 1,
        .HAVE_EXPLICIT_BZERO = 0,
        .HAVE_EXPLICIT_MEMSET = 0,
        .HAVE_EXPM1 = 0,
        .HAVE_FACCESSAT = 1,
        .HAVE_FCHDIR = 1,
        .HAVE_FCHMOD = 1,
        .HAVE_FCHMODAT = 1,
        .HAVE_FCHOWN = 1,
        .HAVE_FCHOWNAT = 1,
        .HAVE_FCNTL_H = 1,
        .HAVE_FDATASYNC = 1,
        .HAVE_FDOPENDIR = 1,
        .HAVE_FDWALK = 1,
        .HAVE_FEXECVE = 1,
        .HAVE_FFI_CLOSURE_ALLOC = null,
        .HAVE_FFI_PREP_CIF_VAR = null,
        .HAVE_FFI_PREP_CLOSURE_LOC = null,
        .HAVE_FLOCK = 1,
        .HAVE_FORK = 1,
        .HAVE_FORK1 = 1,
        .HAVE_FORKPTY = 1,
        .HAVE_FPATHCONF = 1,
        .HAVE_FSEEK64 = null,
        .HAVE_FSEEKO = 1,
        .HAVE_FSTATAT = 1,
        .HAVE_FSTATVFS = 1,
        .HAVE_FSYNC = 1,
        .HAVE_FTELL64 = null,
        .HAVE_FTELLO = 1,
        .HAVE_FTIME = 1,
        .HAVE_FTRUNCATE = 1,
        .HAVE_FUTIMENS = 1,
        .HAVE_FUTIMES = 1,
        .HAVE_FUTIMESAT = 1,
        .HAVE_GAI_STRERROR = null,
        .HAVE_GCC_ASM_FOR_MC68881 = null,
        .HAVE_GCC_ASM_FOR_X64 = @as(?u8, if (target.result.cpu.arch == .x86_64) 1 else null),
        .HAVE_GCC_ASM_FOR_X87 = null,
        .HAVE_GCC_UINT128_T = null,
        .HAVE_GDBM_DASH_NDBM_H = null,
        .HAVE_GDBM_H = null,
        .HAVE_GDBM_NDBM_H = null,
        .HAVE_GETADDRINFO = 1,
        .HAVE_GETC_UNLOCKED = 1,
        .HAVE_GETEGID = 1,
        .HAVE_GETENTROPY = 1,
        .HAVE_GETEUID = 1,
        .HAVE_GETGID = 1,
        .HAVE_GETGRGID = 1,
        .HAVE_GETGRGID_R = null,
        .HAVE_GETGRNAM_R = null,
        .HAVE_GETGROUPLIST = 1,
        .HAVE_GETGROUPS = 1,
        .HAVE_GETHOSTBYADDR = 1,
        .HAVE_GETHOSTBYNAME = 1,
        .HAVE_GETHOSTBYNAME_R = null,
        .HAVE_GETHOSTBYNAME_R_3_ARG = null,
        .HAVE_GETHOSTBYNAME_R_5_ARG = null,
        .HAVE_GETHOSTBYNAME_R_6_ARG = null,
        .HAVE_GETHOSTNAME = 1,
        .HAVE_GETITIMER = 1,
        .HAVE_GETLOADAVG = 1,
        .HAVE_GETLOGIN = 1,
        .HAVE_GETNAMEINFO = 1,
        .HAVE_GETPAGESIZE = 1,
        .HAVE_GETPEERNAME = 1,
        .HAVE_GETPGID = 1,
        .HAVE_GETPGRP = 1,
        .HAVE_GETPID = 1,
        .HAVE_GETPPID = 1,
        .HAVE_GETPRIORITY = 1,
        .HAVE_GETPROTOBYNAME = 1,
        .HAVE_GETPWENT = 1,
        .HAVE_GETPWNAM_R = null,
        .HAVE_GETPWUID = 1,
        .HAVE_GETPWUID_R = null,
        .HAVE_GETRANDOM = 1,
        .HAVE_GETRANDOM_SYSCALL = 1,
        .HAVE_GETRESGID = 1,
        .HAVE_GETRESUID = 1,
        .HAVE_GETRUSAGE = 1,
        .HAVE_GETSERVBYNAME = 1,
        .HAVE_GETSERVBYPORT = 1,
        .HAVE_GETSID = 1,
        .HAVE_GETSOCKNAME = 1,
        .HAVE_GETSPENT = 1,
        .HAVE_GETSPNAM = 1,
        .HAVE_GETUID = 1,
        .HAVE_GETWD = 1,
        .HAVE_GLIBC_MEMMOVE_BUG = null,
        .HAVE_GRP_H = null,
        .HAVE_HSTRERROR = null,
        .HAVE_HTOLE64 = null,
        .HAVE_IEEEFP_H = null,
        .HAVE_IF_NAMEINDEX = null,
        .HAVE_INET_ATON = 1,
        .HAVE_INET_NTOA = 1,
        .HAVE_INET_PTON = 1,
        .HAVE_INITGROUPS = 1,
        .HAVE_INTTYPES_H = 1,
        .HAVE_IO_H = null,
        .HAVE_IPA_PURE_CONST_BUG = null,
        .HAVE_KILL = 1,
        .HAVE_KILLPG = null,
        .HAVE_KQUEUE = 1,
        .HAVE_LANGINFO_H = null,
        .HAVE_LARGEFILE_SUPPORT = null,
        .HAVE_LCHFLAGS = 1,
        .HAVE_LCHMOD = 1,
        .HAVE_LCHOWN = 1,
        .HAVE_LIBB2 = null,
        .HAVE_LIBDB = null,
        .HAVE_LIBDL = null,
        .HAVE_LIBDLD = null,
        .HAVE_LIBIEEE = null,
        .HAVE_LIBINTL_H = null,
        .HAVE_LIBRESOLV = null,
        .HAVE_LIBSENDFILE = null,
        .HAVE_LIBSQLITE3 = null,
        .HAVE_LIBUTIL_H = null,
        .HAVE_LINK = null,
        .HAVE_LINKAT = null,
        .HAVE_LINUX_AUXVEC_H = 1,
        .HAVE_LINUX_CAN_BCM_H = 1,
        .HAVE_LINUX_CAN_H = 1,
        .HAVE_LINUX_CAN_J1939_H = 1,
        .HAVE_LINUX_CAN_RAW_FD_FRAMES = 1,
        .HAVE_LINUX_CAN_RAW_H = 1,
        .HAVE_LINUX_CAN_RAW_JOIN_FILTERS = 1,
        .HAVE_LINUX_FS_H = 1,
        .HAVE_LINUX_LIMITS_H = 1,
        .HAVE_LINUX_MEMFD_H = 1,
        .HAVE_LINUX_NETLINK_H = 1,
        .HAVE_LINUX_QRTR_H = 1,
        .HAVE_LINUX_RANDOM_H = 1,
        .HAVE_LINUX_SOUNDCARD_H = 1,
        .HAVE_LINUX_TIPC_H = 1,
        .HAVE_LINUX_VM_SOCKETS_H = 1,
        .HAVE_LINUX_WAIT_H = 1,
        .HAVE_LISTEN = 1,
        .HAVE_LOCKF = 1,
        .HAVE_LOG1P = 1,
        .HAVE_LOG2 = 1,
        .HAVE_LOGIN_TTY = 1,
        .HAVE_LONG_DOUBLE = 1,
        .HAVE_LSTAT = 1,
        .HAVE_LUTIMES = 1,
        .HAVE_LZMA_H = 1,
        .HAVE_MADVISE = 1,
        .HAVE_MAKEDEV = 1,
        .HAVE_MBRTOWC = 1,
        .HAVE_MEMFD_CREATE = 1,
        .HAVE_MEMRCHR = 1,
        .HAVE_MINIX_CONFIG_H = 1,
        .HAVE_MKDIRAT = 1,
        .HAVE_MKFIFO = 1,
        .HAVE_MKFIFOAT = 1,
        .HAVE_MKNOD = 1,
        .HAVE_MKNODAT = 1,
        .HAVE_MKTIME = 1,
        .HAVE_MMAP = 1,
        .HAVE_MREMAP = 1,
        .HAVE_NANOSLEEP = 1,
        .HAVE_NCURSESW = 1,
        .HAVE_NCURSES_H = 1,
        .HAVE_NDBM_H = 1,
        .HAVE_NDIR_H = 1,
        .HAVE_NETCAN_CAN_H = 1,
        .HAVE_NETDB_H = 1,
        .HAVE_NETINET_IN_H = 1,
        .HAVE_NETPACKET_PACKET_H = 1,
        .HAVE_NET_ETHERNET_H = 1,
        .HAVE_NET_IF_H = 1,
        .HAVE_NICE = 1,
        .HAVE_NON_UNICODE_WCHAR_T_REPRESENTATION = 1,
        .HAVE_OPENAT = 1,
        .HAVE_OPENDIR = 1,
        .HAVE_OPENPTY = 1,
        .HAVE_PANEL_H = 1,
        .HAVE_PATHCONF = 1,
        .HAVE_PAUSE = 1,
        .HAVE_PIPE = 1,
        .HAVE_PIPE2 = 1,
        .HAVE_PLOCK = 1,
        .HAVE_POLL = 1,
        .HAVE_POLL_H = 1,
        .HAVE_POSIX_FADVISE = 1,
        .HAVE_POSIX_FALLOCATE = 1,
        .HAVE_POSIX_SPAWN = 1,
        .HAVE_POSIX_SPAWNP = 1,
        .HAVE_PREAD = 1,
        .HAVE_PREADV = 1,
        .HAVE_PREADV2 = 1,
        .HAVE_PRLIMIT = 1,
        .HAVE_PROCESS_H = 1,
        .HAVE_PROTOTYPES = 1,
        .HAVE_PTHREAD_CONDATTR_SETCLOCK = 1,
        .HAVE_PTHREAD_DESTRUCTOR = 1,
        .HAVE_PTHREAD_GETCPUCLOCKID = 1,
        .HAVE_PTHREAD_H = 1,
        .HAVE_PTHREAD_INIT = 1,
        .HAVE_PTHREAD_KILL = 1,
        .HAVE_PTHREAD_SIGMASK = 1,
        .HAVE_PTHREAD_STUBS = 1,
        .HAVE_PTY_H = 1,
        .HAVE_PWRITE = 1,
        .HAVE_PWRITEV = 1,
        .HAVE_PWRITEV2 = 1,
        .HAVE_READLINE_READLINE_H = 1,
        .HAVE_READLINK = 1,
        .HAVE_READLINKAT = 1,
        .HAVE_READV = 1,
        .HAVE_REALPATH = 1,
        .HAVE_RECVFROM = 1,
        .HAVE_RENAMEAT = 1,
        .HAVE_RL_APPEND_HISTORY = 1,
        .HAVE_RL_CATCH_SIGNAL = 1,
        .HAVE_RL_COMPDISP_FUNC_T = 1,
        .HAVE_RL_COMPLETION_APPEND_CHARACTER = 1,
        .HAVE_RL_COMPLETION_DISPLAY_MATCHES_HOOK = 1,
        .HAVE_RL_COMPLETION_MATCHES = 1,
        .HAVE_RL_COMPLETION_SUPPRESS_APPEND = 1,
        .HAVE_RL_PRE_INPUT_HOOK = 1,
        .HAVE_RL_RESIZE_TERMINAL = 1,
        .HAVE_RPC_RPC_H = 1,
        .HAVE_RTPSPAWN = 1,
        .HAVE_SCHED_GET_PRIORITY_MAX = 1,
        .HAVE_SCHED_H = 1,
        .HAVE_SCHED_RR_GET_INTERVAL = 1,
        .HAVE_SCHED_SETAFFINITY = 1,
        .HAVE_SCHED_SETPARAM = 1,
        .HAVE_SCHED_SETSCHEDULER = 1,
        .HAVE_SEM_CLOCKWAIT = 1,
        .HAVE_SEM_GETVALUE = 1,
        .HAVE_SEM_OPEN = 1,
        .HAVE_SEM_TIMEDWAIT = 1,
        .HAVE_SEM_UNLINK = 1,
        .HAVE_SENDFILE = 1,
        .HAVE_SENDTO = 1,
        .HAVE_SETEGID = 1,
        .HAVE_SETEUID = 1,
        .HAVE_SETGID = 1,
        .HAVE_SETGROUPS = 1,
        .HAVE_SETHOSTNAME = 1,
        .HAVE_SETITIMER = 1,
        .HAVE_SETJMP_H = 1,
        .HAVE_SETLOCALE = 1,
        .HAVE_SETNS = 1,
        .HAVE_SETPGID = 1,
        .HAVE_SETPGRP = 1,
        .HAVE_SETPRIORITY = 1,
        .HAVE_SETREGID = 1,
        .HAVE_SETRESGID = 1,
        .HAVE_SETRESUID = 1,
        .HAVE_SETREUID = 1,
        .HAVE_SETSID = 1,
        .HAVE_SETSOCKOPT = 1,
        .HAVE_SETUID = 1,
        .HAVE_SETVBUF = 1,
        .HAVE_SHADOW_H = 1,
        .HAVE_SHM_OPEN = 1,
        .HAVE_SHM_UNLINK = 1,
        .HAVE_SHUTDOWN = 1,
        .HAVE_SIGACTION = 1,
        .HAVE_SIGALTSTACK = 1,
        .HAVE_SIGFILLSET = 1,
        .HAVE_SIGINFO_T_SI_BAND = 1,
        .HAVE_SIGINTERRUPT = 1,
        .HAVE_SIGNAL_H = 1,
        .HAVE_SIGPENDING = 1,
        .HAVE_SIGRELSE = 1,
        .HAVE_SIGTIMEDWAIT = 1,
        .HAVE_SIGWAIT = 1,
        .HAVE_SIGWAITINFO = 1,
        .HAVE_SNPRINTF = 1,
        .HAVE_SOCKADDR_ALG = 1,
        .HAVE_SOCKADDR_SA_LEN = 1,
        .HAVE_SOCKADDR_STORAGE = 1,
        .HAVE_SOCKET = 1,
        .HAVE_SOCKETPAIR = 1,
        .HAVE_SPAWN_H = 1,
        .HAVE_SPLICE = 1,
        .HAVE_SSIZE_T = 1,
        .HAVE_STATVFS = 1,
        .HAVE_STAT_TV_NSEC = 1,
        .HAVE_STAT_TV_NSEC2 = 1,
        .HAVE_STDINT_H = 1,
        .HAVE_STDIO_H = 1,
        .HAVE_STDLIB_H = 1,
        .HAVE_STD_ATOMIC = 1,
        .HAVE_STRFTIME = 1,
        .HAVE_STRINGS_H = 1,
        .HAVE_STRING_H = 1,
        .HAVE_STRLCPY = 1,
        .HAVE_STROPTS_H = 1,
        .HAVE_STRSIGNAL = 1,
        .HAVE_STRUCT_PASSWD_PW_GECOS = 1,
        .HAVE_STRUCT_PASSWD_PW_PASSWD = 1,
        .HAVE_STRUCT_STAT_ST_BIRTHTIME = 1,
        .HAVE_STRUCT_STAT_ST_BLKSIZE = 1,
        .HAVE_STRUCT_STAT_ST_BLOCKS = 1,
        .HAVE_STRUCT_STAT_ST_FLAGS = 1,
        .HAVE_STRUCT_STAT_ST_GEN = 1,
        .HAVE_STRUCT_STAT_ST_RDEV = 1,
        .HAVE_STRUCT_TM_TM_ZONE = 1,
        .HAVE_SYMLINK = 1,
        .HAVE_SYMLINKAT = 1,
        .HAVE_SYNC = 1,
        .HAVE_SYSCONF = 1,
        .HAVE_SYSEXITS_H = 1,
        .HAVE_SYSLOG_H = 1,
        .HAVE_SYSTEM = 1,
        .HAVE_SYS_AUDIOIO_H = 1,
        .HAVE_SYS_AUXV_H = 1,
        .HAVE_SYS_BSDTTY_H = 1,
        .HAVE_SYS_DEVPOLL_H = 1,
        .HAVE_SYS_DIR_H = 1,
        .HAVE_SYS_ENDIAN_H = 1,
        .HAVE_SYS_EPOLL_H = 1,
        .HAVE_SYS_EVENTFD_H = 1,
        .HAVE_SYS_EVENT_H = 1,
        .HAVE_SYS_FILE_H = 1,
        .HAVE_SYS_IOCTL_H = 1,
        .HAVE_SYS_KERN_CONTROL_H = 1,
        .HAVE_SYS_LOADAVG_H = 1,
        .HAVE_SYS_LOCK_H = 1,
        .HAVE_SYS_MEMFD_H = 1,
        .HAVE_SYS_MKDEV_H = 1,
        .HAVE_SYS_MMAN_H = 1,
        .HAVE_SYS_MODEM_H = 1,
        .HAVE_SYS_NDIR_H = 1,
        .HAVE_SYS_PARAM_H = 1,
        .HAVE_SYS_POLL_H = 1,
        .HAVE_SYS_RANDOM_H = 1,
        .HAVE_SYS_RESOURCE_H = 1,
        .HAVE_SYS_SELECT_H = 1,
        .HAVE_SYS_SENDFILE_H = 1,
        .HAVE_SYS_SOCKET_H = 1,
        .HAVE_SYS_SOUNDCARD_H = 1,
        .HAVE_SYS_STATVFS_H = 1,
        .HAVE_SYS_STAT_H = 1,
        .HAVE_SYS_SYSCALL_H = 1,
        .HAVE_SYS_SYSMACROS_H = 1,
        .HAVE_SYS_SYS_DOMAIN_H = 1,
        .HAVE_SYS_TERMIO_H = 1,
        .HAVE_SYS_TIMES_H = 1,
        .HAVE_SYS_TIME_H = 1,
        .HAVE_SYS_TYPES_H = 1,
        .HAVE_SYS_UIO_H = 1,
        .HAVE_SYS_UN_H = 1,
        .HAVE_SYS_UTSNAME_H = 1,
        .HAVE_SYS_WAIT_H = 1,
        .HAVE_SYS_XATTR_H = 1,
        .HAVE_TCGETPGRP = 1,
        .HAVE_TCSETPGRP = 1,
        .HAVE_TEMPNAM = 1,
        .HAVE_TERMIOS_H = 1,
        .HAVE_TERM_H = 1,
        .HAVE_TIMEGM = 1,
        .HAVE_TIMES = 1,
        .HAVE_TMPFILE = 1,
        .HAVE_TMPNAM = 1,
        .HAVE_TMPNAM_R = 1,
        .HAVE_TM_ZONE = 1,
        .HAVE_TRUNCATE = 1,
        .HAVE_TTYNAME = 1,
        .HAVE_TZNAME = 1,
        .HAVE_UMASK = 1,
        .HAVE_UNAME = 1,
        .HAVE_UNISTD_H = 1,
        .HAVE_UNLINKAT = 1,
        .HAVE_UNSHARE = 1,
        .HAVE_USABLE_WCHAR_T = 1,
        .HAVE_UTIL_H = 1,
        .HAVE_UTIMENSAT = 1,
        .HAVE_UTIMES = 1,
        .HAVE_UTIME_H = 1,
        .HAVE_UTMP_H = 1,
        .HAVE_UUID_CREATE = null,
        .HAVE_UUID_ENC_BE = null,
        .HAVE_UUID_GENERATE_TIME_SAFE = null,
        .HAVE_UUID_H = null,
        .HAVE_UUID_UUID_H = null,
        .HAVE_VFORK = 1,
        .HAVE_WAIT = 1,
        .HAVE_WAIT3 = 1,
        .HAVE_WAIT4 = 1,
        .HAVE_WAITID = 1,
        .HAVE_WAITPID = 1,
        .HAVE_WCHAR_H = 1,
        .HAVE_WCSCOLL = 1,
        .HAVE_WCSFTIME = 1,
        .HAVE_WCSXFRM = 1,
        .HAVE_WMEMCMP = 1,
        .HAVE_WORKING_TZSET = 1,
        .HAVE_WRITEV = 1,
        .HAVE_ZLIB_COPY = null,
        .HAVE_ZLIB_H = null,
        .HAVE__GETPTY = 1,
        .MAJOR_IN_MKDEV = 1,
        .MAJOR_IN_SYSMACROS = 1,
        .MVWDELCH_IS_EXPRESSION = 1,
        .PACKAGE_BUGREPORT = "https://github.com/MidstallSoftware/python.zig/issues",
        .PACKAGE_NAME = "python",
        .PACKAGE_STRING = "python",
        .PACKAGE_TARNAME = "python-3.12.2",
        .PACKAGE_URL = "https://github.com/MidstallSoftware/python.zig",
        .PACKAGE_VERSION = "3.12.2",
        .POSIX_SEMAPHORES_NOT_ENABLED = 1,
        .PTHREAD_KEY_T_IS_COMPATIBLE_WITH_INT = 1,
        .PTHREAD_SYSTEM_SCHED_SUPPORTED = 1,
        .PYLONG_BITS_IN_DIGIT = 1,
        .PY_BUILTIN_HASHLIB_HASHES = 1,
        .PY_COERCE_C_LOCALE = 1,
        .PY_HAVE_PERF_TRAMPOLINE = 1,
        .PY_SQLITE_ENABLE_LOAD_EXTENSION = 1,
        .PY_SQLITE_HAVE_SERIALIZE = 1,
        .PY_SSL_DEFAULT_CIPHERS = 1,
        .PY_SSL_DEFAULT_CIPHER_STRING = 1,
        .PY_SUPPORT_TIER = 1,
        .Py_DEBUG = 1,
        .Py_ENABLE_SHARED = 1,
        .Py_HASH_ALGORITHM = 1,
        .Py_STATS = 1,
        .Py_SUNOS_VERSION = 1,
        .Py_TRACE_REFS = 1,
        .RETSIGTYPE = 1,
        .SETPGRP_HAVE_ARG = 1,
        .SIGNED_RIGHT_SHIFT_ZERO_FILLS = 1,
        .SIZEOF_DOUBLE = null,
        .SIZEOF_FLOAT = null,
        .SIZEOF_FPOS_T = null,
        .SIZEOF_INT = null,
        .SIZEOF_LONG = null,
        .SIZEOF_LONG_DOUBLE = null,
        .SIZEOF_LONG_LONG = null,
        .SIZEOF_OFF_T = null,
        .SIZEOF_PID_T = null,
        .SIZEOF_PTHREAD_KEY_T = null,
        .SIZEOF_PTHREAD_T = null,
        .SIZEOF_SHORT = null,
        .SIZEOF_SIZE_T = null,
        .SIZEOF_TIME_T = null,
        .SIZEOF_UINTPTR_T = null,
        .SIZEOF_VOID_P = null,
        .SIZEOF_WCHAR_T = null,
        .SIZEOF__BOOL = null,
        .STDC_HEADERS = 1,
        .SYS_SELECT_WITH_SYS_TIME = 1,
        .THREAD_STACK_SIZE = 1,
        .TIMEMODULE_LIB = 1,
        .TM_IN_SYS_TIME = 1,
        .USE_COMPUTED_GOTOS = 1,
        ._ALL_SOURCE = 1,
        .__EXTENSIONS__ = 1,
        ._GNU_SOURCE = 1,
        ._HPUX_ALT_XOPEN_SOCKET_API = 1,
        ._MINIX = 1,
        ._OPENBSD_SOURCE = 1,
        ._POSIX_SOURCE = 1,
        ._POSIX_1_SOURCE = 1,
        ._POSIX_PTHREAD_SEMANTICS = 1,
        .__STDC_WANT_IEC_60559_ATTRIBS_EXT__ = 1,
        .__STDC_WANT_IEC_60559_BFP_EXT__ = 1,
        .__STDC_WANT_IEC_60559_DFP_EXT__ = 1,
        .__STDC_WANT_IEC_60559_FUNCS_EXT__ = 1,
        .__STDC_WANT_IEC_60559_TYPES_EXT__ = 1,
        .__STDC_WANT_LIB_EXT2__ = 1,
        .__STDC_WANT_MATH_SPEC_FUNCS__ = 1,
        ._TANDEM_SOURCE = 1,
        .WINDOW_HAS_FLAGS = null,
        .WITH_DECIMAL_CONTEXTVAR = null,
        .WITH_DOC_STRINGS = null,
        .WITH_DTRACE = null,
        .WITH_DYLD = null,
        .WITH_EDITLINE = null,
        .WITH_FREELISTS = null,
        .WITH_LIBINTL = null,
        .WITH_NEXT_FRAMEWORK = null,
        .WITH_PYMALLOC = null,
        .WITH_VALGRIND = null,
        .WORDS_BIGENDIAN = null,
        .X87_DOUBLE_ROUNDING = null,
        ._BSD_SOURCE = null,
        ._DARWIN_C_SOURCE = null,
        ._FILE_OFFSET_BITS = 1,
        ._INCLUDE__STDC_A1_SOURCE = 1,
        ._LARGEFILE_SOURCE = 1,
        ._LARGE_FILES = null,
        ._NETBSD_SOURCE = null,
        ._POSIX_C_SOURCE = 1,
        ._POSIX_THREADS = 1,
        ._PYTHONFRAMEWORK = "Python",
        ._REENTRANT = null,
        ._WASI_EMULATED_GETPID = null,
        ._WASI_EMULATED_PROCESS_CLOCKS = null,
        ._WASI_EMULATED_SIGNAL = null,
        ._XOPEN_SOURCE = null,
        ._XOPEN_SOURCE_EXTENDED = null,
        .__BSD_VISIBLE = null,
        .clock_t = null,
        .@"const" = null,
        .gid_t = null,
        .mode_t = null,
        .off_t = null,
        .pid_t = null,
        .signed = null,
        .size_t = null,
        .socklen_t = null,
        .uid_t = null,
    });

    const freezeModule = b.addExecutable(.{
        .name = "freeze-module",
        .target = b.host,
        .link_libc = true,
        .linkage = linkage,
    });

    freezeModule.addIncludePath(source.path("Include"));
    freezeModule.addConfigHeader(pyconfigHeader);

    freezeModule.addCSourceFile(.{ .file = modulesConfig.getOutput() });
    addObjsOmitFrozen(freezeModule, source);

    freezeModule.addCSourceFiles(.{
        .files = &.{
            source.path("Modules/getpath_noop.c").getPath(b),
            source.path("Programs/_freeze_module.c").getPath(b),
        },
    });

    b.installArtifact(freezeModule);

    const lib = std.Build.Step.Compile.create(b, .{
        .name = "python3",
        .root_module = .{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        },
        .kind = .lib,
        .linkage = linkage,
        .version = .{
            .major = 1,
            .minor = 0,
            .patch = 0,
        },
    });

    lib.addIncludePath(source.path("Include"));
    lib.addConfigHeader(pyconfigHeader);

    {
        const deepfreeze = DeepfreezeStep.create(b, source.path("Tools/build/deepfreeze.py"));

        //deepfreeze.addModule(addFrozenModule(freezeModule, source.path("Lib/importlib/_bootstrap.py"), "importlib._bootstrap.h"), "importlib._bootstrap");

        //lib.addCSourceFile(.{ .file = .{
        //    .generated = &deepfreeze.output_file,
        //} });
        _ = deepfreeze;
    }

    lib.addCSourceFile(.{ .file = modulesConfig.getOutput() });
    addObjsOmitFrozen(lib, source);

    lib.addCSourceFiles(.{
        .files = &.{
            source.path("Modules/getpath.c").getPath(b),
            source.path("Python/frozen.c").getPath(b),
        },
    });

    b.installArtifact(lib);
}