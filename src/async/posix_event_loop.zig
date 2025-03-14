const bun = @import("root").bun;
const Output = bun.Output;
const JSC = bun.JSC;
const uws = bun.uws;
const Environment = bun.Environment;
const std = @import("std");

pub const Loop = uws.Loop;

/// Track if an object whose file descriptor is being watched should keep the event loop alive.
/// This is not reference counted. It only tracks active or inactive.
pub const KeepAlive = struct {
    status: Status = .inactive,

    const log = Output.scoped(.KeepAlive, false);

    const Status = enum { active, inactive, done };

    pub inline fn isActive(this: KeepAlive) bool {
        return this.status == .active;
    }

    /// Make calling ref() on this poll into a no-op.
    pub fn disable(this: *KeepAlive) void {
        this.unref(JSC.VirtualMachine.get());
        this.status = .done;
    }

    /// Only intended to be used from EventLoop.Pollable
    pub fn deactivate(this: *KeepAlive, loop: *Loop) void {
        if (this.status != .active)
            return;

        this.status = .inactive;
        loop.subActive(1);
    }

    /// Only intended to be used from EventLoop.Pollable
    pub fn activate(this: *KeepAlive, loop: *Loop) void {
        if (this.status != .inactive)
            return;

        this.status = .active;
        loop.addActive(1);
    }

    pub fn init() KeepAlive {
        return .{};
    }

    /// Prevent a poll from keeping the process alive.
    pub fn unref(this: *KeepAlive, event_loop_ctx_: anytype) void {
        const event_loop_ctx = JSC.AbstractVM(event_loop_ctx_);
        if (this.status != .active)
            return;
        this.status = .inactive;
        // vm.event_loop_handle.?.subActive(1);
        event_loop_ctx.platformEventLoop().subActive(1);
    }

    /// From another thread, Prevent a poll from keeping the process alive.
    pub fn unrefConcurrently(this: *KeepAlive, event_loop_ctx_: anytype) void {
        const event_loop_ctx = JSC.AbstractVM(event_loop_ctx_);
        if (this.status != .active)
            return;
        this.status = .inactive;
        // vm.event_loop_handle.?.unrefConcurrently();
        event_loop_ctx.platformEventLoop().unrefConcurrently();
    }

    /// Prevent a poll from keeping the process alive on the next tick.
    pub fn unrefOnNextTick(this: *KeepAlive, event_loop_ctx_: anytype) void {
        const event_loop_ctx = JSC.AbstractVM(event_loop_ctx_);
        if (this.status != .active)
            return;
        this.status = .inactive;
        // vm.pending_unref_counter +|= 1;
        event_loop_ctx.incrementPendingUnrefCounter();
    }

    /// From another thread, prevent a poll from keeping the process alive on the next tick.
    pub fn unrefOnNextTickConcurrently(this: *KeepAlive, vm: *JSC.VirtualMachine) void {
        if (this.status != .active)
            return;
        this.status = .inactive;
        _ = @atomicRmw(@TypeOf(vm.pending_unref_counter), &vm.pending_unref_counter, .Add, 1, .Monotonic);
    }

    /// Allow a poll to keep the process alive.
    pub fn ref(this: *KeepAlive, event_loop_ctx_: anytype) void {
        const event_loop_ctx = JSC.AbstractVM(event_loop_ctx_);
        if (this.status != .inactive)
            return;
        this.status = .active;
        event_loop_ctx.platformEventLoop().ref();
        // vm.event_loop_handle.?.ref();
    }

    /// Allow a poll to keep the process alive.
    pub fn refConcurrently(this: *KeepAlive, event_loop_ctx_: anytype) void {
        const event_loop_ctx = JSC.AbstractVM(event_loop_ctx_);
        if (this.status != .inactive)
            return;
        this.status = .active;
        // vm.event_loop_handle.?.refConcurrently();
        event_loop_ctx.platformEventLoop().refConcurrently();
    }

    pub fn refConcurrentlyFromEventLoop(this: *KeepAlive, loop: *JSC.EventLoop) void {
        this.refConcurrently(loop.virtual_machine);
    }

    pub fn unrefConcurrentlyFromEventLoop(this: *KeepAlive, loop: *JSC.EventLoop) void {
        this.unrefConcurrently(loop.virtual_machine);
    }
};

const KQueueGenerationNumber = if (Environment.isMac and Environment.allow_assert) usize else u0;
pub const FilePoll = struct {
    var max_generation_number: KQueueGenerationNumber = 0;

    fd: bun.FileDescriptor = invalid_fd,
    flags: Flags.Set = Flags.Set{},
    owner: Owner = undefined,

    /// We re-use FilePoll objects to avoid allocating new ones.
    ///
    /// That means we might run into situations where the event is stale.
    /// on macOS kevent64 has an extra pointer field so we use it for that
    /// linux doesn't have a field like that
    generation_number: KQueueGenerationNumber = 0,
    next_to_free: ?*FilePoll = null,

    event_loop_kind: JSC.EventLoopKind = .js,

    const FileReader = JSC.WebCore.FileReader;
    const FileSink = JSC.WebCore.FileSink;
    const FileSinkMini = JSC.WebCore.FileSinkMini;
    const FIFO = JSC.WebCore.FIFO;
    const FIFOMini = JSC.WebCore.FIFOMini;
    const ShellSubprocess = bun.ShellSubprocess;
    const ShellSubprocessMini = bun.shell.SubprocessMini;
    const ShellBufferedWriter = bun.shell.Interpreter.BufferedWriter;
    const ShellBufferedWriterMini = bun.shell.InterpreterMini.BufferedWriter;
    const ShellBufferedInput = bun.ShellSubprocess.BufferedInput;
    const ShellBufferedInputMini = bun.shell.SubprocessMini.BufferedInput;
    const ShellSubprocessCapturedBufferedWriter = bun.ShellSubprocess.BufferedOutput.CapturedBufferedWriter;
    const ShellSubprocessCapturedBufferedWriterMini = bun.shell.SubprocessMini.BufferedOutput.CapturedBufferedWriter;
    const ShellBufferedOutput = bun.shell.Subprocess.BufferedOutput;
    const ShellBufferedOutputMini = bun.shell.SubprocessMini.BufferedOutput;

    const Subprocess = JSC.Subprocess;
    const BufferedInput = Subprocess.BufferedInput;
    const BufferedOutput = Subprocess.BufferedOutput;
    const DNSResolver = JSC.DNS.DNSResolver;
    const GetAddrInfoRequest = JSC.DNS.GetAddrInfoRequest;
    const Deactivated = opaque {
        pub var owner: Owner = Owner.init(@as(*Deactivated, @ptrFromInt(@as(usize, 0xDEADBEEF))));
    };

    const LifecycleScriptSubprocessOutputReader = bun.install.LifecycleScriptSubprocess.OutputReader;
    const LifecycleScriptSubprocessPid = bun.install.LifecycleScriptSubprocess.PidPollData;

    pub const Owner = bun.TaggedPointerUnion(.{
        FileReader,
        FileSink,
        FileSinkMini,
        Subprocess,

        ShellSubprocess,
        ShellSubprocessMini,
        ShellBufferedWriter,
        ShellBufferedWriterMini,
        ShellBufferedInput,
        ShellBufferedInputMini,
        ShellSubprocessCapturedBufferedWriter,
        ShellSubprocessCapturedBufferedWriterMini,
        ShellBufferedOutput,
        ShellBufferedOutputMini,

        BufferedInput,
        FIFO,
        FIFOMini,
        Deactivated,
        DNSResolver,
        GetAddrInfoRequest,
        LifecycleScriptSubprocessOutputReader,
        LifecycleScriptSubprocessPid,
    });

    fn updateFlags(poll: *FilePoll, updated: Flags.Set) void {
        var flags = poll.flags;
        flags.remove(.readable);
        flags.remove(.writable);
        flags.remove(.process);
        flags.remove(.machport);
        flags.remove(.eof);
        flags.remove(.hup);

        flags.setUnion(updated);
        poll.flags = flags;
    }

    pub fn onKQueueEvent(poll: *FilePoll, _: *Loop, kqueue_event: *const std.os.system.kevent64_s) void {
        if (KQueueGenerationNumber != u0)
            std.debug.assert(poll.generation_number == kqueue_event.ext[0]);

        poll.updateFlags(Flags.fromKQueueEvent(kqueue_event.*));
        poll.onUpdate(kqueue_event.data);
    }

    pub fn onEpollEvent(poll: *FilePoll, _: *Loop, epoll_event: *std.os.linux.epoll_event) void {
        poll.updateFlags(Flags.fromEpollEvent(epoll_event.*));
        poll.onUpdate(0);
    }

    pub fn clearEvent(poll: *FilePoll, flag: Flags) void {
        poll.flags.remove(flag);
    }

    pub fn isReadable(this: *FilePoll) bool {
        const readable = this.flags.contains(.readable);
        this.flags.remove(.readable);
        return readable;
    }

    pub fn isHUP(this: *FilePoll) bool {
        const readable = this.flags.contains(.hup);
        this.flags.remove(.hup);
        return readable;
    }

    pub fn isEOF(this: *FilePoll) bool {
        const readable = this.flags.contains(.eof);
        this.flags.remove(.eof);
        return readable;
    }

    pub fn isWritable(this: *FilePoll) bool {
        const readable = this.flags.contains(.writable);
        this.flags.remove(.writable);
        return readable;
    }

    pub fn deinit(this: *FilePoll) void {
        switch (this.event_loop_kind) {
            .js => {
                const vm = JSC.VirtualMachine.get();
                const handle = JSC.AbstractVM(vm);
                // const loop = vm.event_loop_handle.?;
                const loop = handle.platformEventLoop();
                const file_polls = handle.filePolls();
                this.deinitPossiblyDefer(vm, loop, file_polls, false);
            },
            .mini => {
                const vm = JSC.MiniEventLoop.global;
                const handle = JSC.AbstractVM(vm);
                // const loop = vm.event_loop_handle.?;
                const loop = handle.platformEventLoop();
                const file_polls = handle.filePolls();
                this.deinitPossiblyDefer(vm, loop, file_polls, false);
            },
        }
    }

    pub fn deinitForceUnregister(this: *FilePoll) void {
        switch (this.event_loop_kind) {
            .js => {
                var vm = JSC.VirtualMachine.get();
                const loop = vm.event_loop_handle.?;
                this.deinitPossiblyDefer(vm, loop, vm.rareData().filePolls(vm), true);
            },
            .mini => {
                var vm = JSC.MiniEventLoop.global;
                const loop = vm.loop;
                this.deinitPossiblyDefer(vm, loop, vm.filePolls(), true);
            },
        }
    }

    fn deinitPossiblyDefer(this: *FilePoll, vm: anytype, loop: *Loop, polls: *FilePoll.Store, force_unregister: bool) void {
        _ = this.unregister(loop, force_unregister);

        this.owner = Deactivated.owner;
        const was_ever_registered = this.flags.contains(.was_ever_registered);
        this.flags = Flags.Set{};
        this.fd = invalid_fd;
        polls.put(this, vm, was_ever_registered);
    }

    pub fn deinitWithVM(this: *FilePoll, vm_: anytype) void {
        const vm = JSC.AbstractVM(vm_);
        // const loop = vm.event_loop_handle.?;
        const loop = vm.platformEventLoop();
        this.deinitPossiblyDefer(vm_, loop, vm.filePolls(), false);
    }

    pub fn isRegistered(this: *const FilePoll) bool {
        return this.flags.contains(.poll_writable) or this.flags.contains(.poll_readable) or this.flags.contains(.poll_process) or this.flags.contains(.poll_machport);
    }

    const kqueue_or_epoll = if (Environment.isMac) "kevent" else "epoll";

    pub fn onUpdate(poll: *FilePoll, size_or_offset: i64) void {
        if (poll.flags.contains(.one_shot) and !poll.flags.contains(.needs_rearm)) {
            poll.flags.insert(.needs_rearm);
        }

        var ptr = poll.owner;
        switch (ptr.tag()) {
            @field(Owner.Tag, bun.meta.typeBaseName(@typeName(FIFO))) => {
                log("onUpdate " ++ kqueue_or_epoll ++ " (fd: {d}) FIFO", .{poll.fd});
                ptr.as(FIFO).ready(size_or_offset, poll.flags.contains(.hup));
            },
            @field(Owner.Tag, bun.meta.typeBaseName(@typeName(ShellBufferedInput))) => {
                log("onUpdate " ++ kqueue_or_epoll ++ " (fd: {d}) ShellBufferedInput", .{poll.fd});
                ptr.as(ShellBufferedInput).onPoll(size_or_offset, 0);
            },
            @field(Owner.Tag, "Subprocess") => {
                log("onUpdate " ++ kqueue_or_epoll ++ " (fd: {d}) Subprocess", .{poll.fd});
                var loader = ptr.as(JSC.Subprocess);

                loader.onExitNotificationTask();
            },
            @field(Owner.Tag, bun.meta.typeBaseName(@typeName(ShellBufferedWriter))) => {
                log("onUpdate " ++ kqueue_or_epoll ++ " (fd: {d}) ShellBufferedWriter", .{poll.fd});
                var loader = ptr.as(ShellBufferedWriter);
                loader.onPoll(size_or_offset, 0);
            },
            @field(Owner.Tag, bun.meta.typeBaseName(@typeName(ShellBufferedWriterMini))) => {
                log("onUpdate " ++ kqueue_or_epoll ++ " (fd: {d}) ShellBufferedWriterMini", .{poll.fd});
                var loader = ptr.as(ShellBufferedWriterMini);
                loader.onPoll(size_or_offset, 0);
            },
            @field(Owner.Tag, bun.meta.typeBaseName(@typeName(ShellSubprocessCapturedBufferedWriter))) => {
                log("onUpdate " ++ kqueue_or_epoll ++ " (fd: {d}) ShellSubprocessCapturedBufferedWriter", .{poll.fd});
                var loader = ptr.as(ShellSubprocessCapturedBufferedWriter);
                loader.onPoll(size_or_offset, 0);
            },
            @field(Owner.Tag, bun.meta.typeBaseName(@typeName(ShellSubprocessCapturedBufferedWriterMini))) => {
                log("onUpdate " ++ kqueue_or_epoll ++ " (fd: {d}) ShellSubprocessCapturedBufferedWriterMini", .{poll.fd});
                var loader = ptr.as(ShellSubprocessCapturedBufferedWriterMini);
                loader.onPoll(size_or_offset, 0);
            },
            @field(Owner.Tag, bun.meta.typeBaseName(@typeName(ShellSubprocess))) => {
                log("onUpdate " ++ kqueue_or_epoll ++ " (fd: {d}) ShellSubprocess", .{poll.fd});
                var loader = ptr.as(ShellSubprocess);

                loader.onExitNotificationTask();
            },
            @field(Owner.Tag, bun.meta.typeBaseName(@typeName(ShellSubprocessMini))) => {
                log("onUpdate " ++ kqueue_or_epoll ++ " (fd: {d}) ShellSubprocessMini", .{poll.fd});
                var loader = ptr.as(ShellSubprocessMini);

                loader.onExitNotificationTask();
            },
            @field(Owner.Tag, bun.meta.typeBaseName(@typeName(JSC.WebCore.FileSink))) => {
                log("onUpdate " ++ kqueue_or_epoll ++ " (fd: {d}) FileSink", .{poll.fd});
                var loader = ptr.as(JSC.WebCore.FileSink);
                loader.onPoll(size_or_offset, 0);
            },

            @field(Owner.Tag, "DNSResolver") => {
                log("onUpdate " ++ kqueue_or_epoll ++ " (fd: {d}) DNSResolver", .{poll.fd});
                var loader: *DNSResolver = ptr.as(DNSResolver);
                loader.onDNSPoll(poll);
            },

            @field(Owner.Tag, "GetAddrInfoRequest") => {
                if (comptime !Environment.isMac) {
                    unreachable;
                }

                log("onUpdate " ++ kqueue_or_epoll ++ " (fd: {d}) GetAddrInfoRequest", .{poll.fd});
                var loader: *GetAddrInfoRequest = ptr.as(GetAddrInfoRequest);
                loader.onMachportChange();
            },

            @field(Owner.Tag, "OutputReader") => {
                log("onUpdate " ++ kqueue_or_epoll ++ " (fd: {d}) OutputReader", .{poll.fd});
                var output: *LifecycleScriptSubprocessOutputReader = ptr.as(LifecycleScriptSubprocessOutputReader);
                output.onPoll(size_or_offset);
            },
            @field(Owner.Tag, "PidPollData") => {
                log("onUpdate " ++ kqueue_or_epoll ++ " (fd: {d}) LifecycleScriptSubprocess Pid", .{poll.fd});
                var loader: *bun.install.LifecycleScriptSubprocess = @ptrCast(ptr.as(LifecycleScriptSubprocessPid));
                loader.onProcessUpdate(size_or_offset);
            },

            else => {
                const possible_name = Owner.typeNameFromTag(@intFromEnum(ptr.tag()));
                log("onUpdate " ++ kqueue_or_epoll ++ " (fd: {d}) disconnected? (maybe: {s})", .{ poll.fd, possible_name orelse "<unknown>" });
            },
        }
    }

    pub const Flags = enum {
        // What are we asking the event loop about?

        /// Poll for readable events
        poll_readable,

        /// Poll for writable events
        poll_writable,

        /// Poll for process-related events
        poll_process,

        /// Poll for machport events
        poll_machport,

        // What did the event loop tell us?
        readable,
        writable,
        process,
        eof,
        hup,
        machport,

        // What is the type of file descriptor?
        fifo,
        tty,

        one_shot,
        needs_rearm,

        has_incremented_poll_count,
        has_incremented_active_count,
        closed,

        keeps_event_loop_alive,

        nonblocking,

        was_ever_registered,
        ignore_updates,

        pub fn poll(this: Flags) Flags {
            return switch (this) {
                .readable => .poll_readable,
                .writable => .poll_writable,
                .process => .poll_process,
                .machport => .poll_machport,
                else => this,
            };
        }

        pub const Set = std.EnumSet(Flags);
        pub const Struct = std.enums.EnumFieldStruct(Flags, bool, false);

        pub fn fromKQueueEvent(kqueue_event: std.os.system.kevent64_s) Flags.Set {
            var flags = Flags.Set{};
            if (kqueue_event.filter == std.os.system.EVFILT_READ) {
                flags.insert(Flags.readable);
                log("readable", .{});
                if (kqueue_event.flags & std.os.system.EV_EOF != 0) {
                    flags.insert(Flags.hup);
                    log("hup", .{});
                }
            } else if (kqueue_event.filter == std.os.system.EVFILT_WRITE) {
                flags.insert(Flags.writable);
                log("writable", .{});
                if (kqueue_event.flags & std.os.system.EV_EOF != 0) {
                    flags.insert(Flags.hup);
                    log("hup", .{});
                }
            } else if (kqueue_event.filter == std.os.system.EVFILT_PROC) {
                log("proc", .{});
                flags.insert(Flags.process);
            } else if (kqueue_event.filter == std.os.system.EVFILT_MACHPORT) {
                log("machport", .{});
                flags.insert(Flags.machport);
            }
            return flags;
        }

        pub fn fromEpollEvent(epoll: std.os.linux.epoll_event) Flags.Set {
            var flags = Flags.Set{};
            if (epoll.events & std.os.linux.EPOLL.IN != 0) {
                flags.insert(Flags.readable);
                log("readable", .{});
            }
            if (epoll.events & std.os.linux.EPOLL.OUT != 0) {
                flags.insert(Flags.writable);
                log("writable", .{});
            }
            if (epoll.events & std.os.linux.EPOLL.ERR != 0) {
                flags.insert(Flags.eof);
                log("eof", .{});
            }
            if (epoll.events & std.os.linux.EPOLL.HUP != 0) {
                flags.insert(Flags.hup);
                log("hup", .{});
            }
            return flags;
        }
    };

    const HiveArray = bun.HiveArray(FilePoll, 128).Fallback;

    // We defer freeing FilePoll until the end of the next event loop iteration
    // This ensures that we don't free a FilePoll before the next callback is called
    pub const Store = struct {
        hive: HiveArray,
        pending_free_head: ?*FilePoll = null,
        pending_free_tail: ?*FilePoll = null,

        const log = Output.scoped(.FilePoll, false);

        pub fn init(allocator: std.mem.Allocator) Store {
            return .{
                .hive = HiveArray.init(allocator),
            };
        }

        pub fn get(this: *Store) *FilePoll {
            return this.hive.get();
        }

        pub fn processDeferredFrees(this: *Store) void {
            var next = this.pending_free_head;
            while (next) |current| {
                next = current.next_to_free;
                current.next_to_free = null;
                this.hive.put(current);
            }
            this.pending_free_head = null;
            this.pending_free_tail = null;
        }

        pub fn put(this: *Store, poll: *FilePoll, vm: anytype, ever_registered: bool) void {
            if (@TypeOf(vm) != *JSC.VirtualMachine and @TypeOf(vm) != *JSC.MiniEventLoop) {
                @compileError("Bad vm: " ++ @typeName(@TypeOf(vm)));
            }

            if (!ever_registered) {
                this.hive.put(poll);
                return;
            }

            std.debug.assert(poll.next_to_free == null);

            if (this.pending_free_tail) |tail| {
                std.debug.assert(this.pending_free_head != null);
                std.debug.assert(tail.next_to_free == null);
                tail.next_to_free = poll;
            }

            if (this.pending_free_head == null) {
                this.pending_free_head = poll;
                std.debug.assert(this.pending_free_tail == null);
            }

            poll.flags.insert(.ignore_updates);
            this.pending_free_tail = poll;
            std.debug.assert(vm.after_event_loop_callback == null or vm.after_event_loop_callback == @as(?JSC.OpaqueCallback, @ptrCast(&processDeferredFrees)));
            vm.after_event_loop_callback = @ptrCast(&processDeferredFrees);
            vm.after_event_loop_callback_ctx = this;
        }
    };

    const log = Output.scoped(.FilePoll, false);

    pub inline fn isActive(this: *const FilePoll) bool {
        return this.flags.contains(.has_incremented_poll_count);
    }

    pub inline fn isWatching(this: *const FilePoll) bool {
        return !this.flags.contains(.needs_rearm) and (this.flags.contains(.poll_readable) or this.flags.contains(.poll_writable) or this.flags.contains(.poll_process));
    }

    /// This decrements the active counter if it was previously incremented
    /// "active" controls whether or not the event loop should potentially idle
    pub fn disableKeepingProcessAlive(this: *FilePoll, event_loop_ctx_: anytype) void {
        const event_loop_ctx = JSC.AbstractVM(event_loop_ctx_);
        // log("{x} disableKeepingProcessAlive", .{@intFromPtr(this)});
        // vm.event_loop_handle.?.subActive(@as(u32, @intFromBool(this.flags.contains(.has_incremented_active_count))));
        event_loop_ctx.platformEventLoop().subActive(@as(u32, @intFromBool(this.flags.contains(.has_incremented_active_count))));
        this.flags.remove(.keeps_event_loop_alive);
        this.flags.remove(.has_incremented_active_count);
    }

    pub inline fn canEnableKeepingProcessAlive(this: *const FilePoll) bool {
        return this.flags.contains(.keeps_event_loop_alive) and this.flags.contains(.has_incremented_poll_count);
    }

    pub fn enableKeepingProcessAlive(this: *FilePoll, event_loop_ctx_: anytype) void {
        const event_loop_ctx = JSC.AbstractVM(event_loop_ctx_);
        // log("{x} enableKeepingProcessAlive", .{@intFromPtr(this)});
        if (this.flags.contains(.closed))
            return;

        // vm.event_loop_handle.?.addActive(@as(u32, @intFromBool(!this.flags.contains(.has_incremented_active_count))));
        event_loop_ctx.platformEventLoop().addActive(@as(u32, @intFromBool(!this.flags.contains(.has_incremented_active_count))));
        this.flags.insert(.keeps_event_loop_alive);
        this.flags.insert(.has_incremented_active_count);
    }

    /// Only intended to be used from EventLoop.Pollable
    fn deactivate(this: *FilePoll, loop: *Loop) void {
        loop.num_polls -= @as(i32, @intFromBool(this.flags.contains(.has_incremented_poll_count)));
        this.flags.remove(.has_incremented_poll_count);

        loop.subActive(@as(u32, @intFromBool(this.flags.contains(.has_incremented_active_count))));
        this.flags.remove(.keeps_event_loop_alive);
        this.flags.remove(.has_incremented_active_count);
    }

    /// Only intended to be used from EventLoop.Pollable
    fn activate(this: *FilePoll, loop: *Loop) void {
        this.flags.remove(.closed);

        loop.num_polls += @as(i32, @intFromBool(!this.flags.contains(.has_incremented_poll_count)));
        this.flags.insert(.has_incremented_poll_count);

        if (this.flags.contains(.keeps_event_loop_alive)) {
            loop.addActive(@as(u32, @intFromBool(!this.flags.contains(.has_incremented_active_count))));
            this.flags.insert(.has_incremented_active_count);
        }
    }

    pub fn init(vm: anytype, fd: bun.FileDescriptor, flags: Flags.Struct, comptime Type: type, owner: *Type) *FilePoll {
        return initWithOwner(vm, fd, flags, Owner.init(owner));
    }

    pub fn initWithOwner(vm_: anytype, fd: bun.FileDescriptor, flags: Flags.Struct, owner: Owner) *FilePoll {
        const vm = JSC.AbstractVM(vm_);
        var poll = vm.allocFilePoll();
        poll.fd = fd;
        poll.flags = Flags.Set.init(flags);
        poll.owner = owner;
        poll.next_to_free = null;
        poll.event_loop_kind = if (comptime @TypeOf(vm_) == *JSC.VirtualMachine) .js else .mini;

        if (KQueueGenerationNumber != u0) {
            max_generation_number +%= 1;
            poll.generation_number = max_generation_number;
        }
        return poll;
    }

    pub fn initWithPackageManager(m: *bun.PackageManager, fd: bun.FileDescriptor, flags: Flags.Struct, owner: anytype) *FilePoll {
        return initWithPackageManagerWithOwner(m, fd, flags, Owner.init(owner));
    }

    pub fn initWithPackageManagerWithOwner(manager: *bun.PackageManager, fd: bun.FileDescriptor, flags: Flags.Struct, owner: Owner) *FilePoll {
        var poll = manager.file_poll_store.get();
        poll.fd = fd;
        poll.flags = Flags.Set.init(flags);
        poll.owner = owner;
        poll.next_to_free = null;
        // Well I'm not sure what to put here because it looks bun install doesn't use JSC event loop or mini event loop
        poll.event_loop_kind = .js;

        if (KQueueGenerationNumber != u0) {
            max_generation_number +%= 1;
            poll.generation_number = max_generation_number;
        }

        return poll;
    }

    pub inline fn canRef(this: *const FilePoll) bool {
        if (this.flags.contains(.disable))
            return false;

        return !this.flags.contains(.has_incremented_poll_count);
    }

    pub inline fn canUnref(this: *const FilePoll) bool {
        return this.flags.contains(.has_incremented_poll_count);
    }

    /// Prevent a poll from keeping the process alive.
    pub fn unref(this: *FilePoll, event_loop_ctx_: anytype) void {
        log("unref", .{});
        this.disableKeepingProcessAlive(event_loop_ctx_);
    }

    /// Allow a poll to keep the process alive.
    pub fn ref(this: *FilePoll, event_loop_ctx_: anytype) void {
        if (this.flags.contains(.closed))
            return;

        log("ref", .{});

        this.enableKeepingProcessAlive(event_loop_ctx_);
    }

    pub fn onEnded(this: *FilePoll, event_loop_ctx_: anytype) void {
        const event_loop_ctx = JSC.AbstractVM(event_loop_ctx_);
        this.flags.remove(.keeps_event_loop_alive);
        this.flags.insert(.closed);
        // this.deactivate(vm.event_loop_handle.?);
        this.deactivate(event_loop_ctx.platformEventLoop());
    }

    pub fn onTick(loop: *Loop, tagged_pointer: ?*anyopaque) callconv(.C) void {
        var tag = Pollable.from(tagged_pointer);

        if (tag.tag() != @field(Pollable.Tag, "FilePoll"))
            return;

        var file_poll: *FilePoll = tag.as(FilePoll);
        if (file_poll.flags.contains(.ignore_updates)) {
            return;
        }

        if (comptime Environment.isMac)
            onKQueueEvent(file_poll, loop, &loop.ready_polls[@as(usize, @intCast(loop.current_ready_poll))])
        else if (comptime Environment.isLinux)
            onEpollEvent(file_poll, loop, &loop.ready_polls[@as(usize, @intCast(loop.current_ready_poll))]);
    }

    const Pollable = bun.TaggedPointerUnion(.{
        FilePoll,
        Deactivated,
    });

    comptime {
        @export(onTick, .{ .name = "Bun__internal_dispatch_ready_poll" });
    }

    const timeout = std.mem.zeroes(std.os.timespec);
    const kevent = std.c.kevent;
    const linux = std.os.linux;

    pub fn register(this: *FilePoll, loop: *Loop, flag: Flags, one_shot: bool) JSC.Maybe(void) {
        return registerWithFd(this, loop, flag, one_shot, this.fd);
    }
    pub fn registerWithFd(this: *FilePoll, loop: *Loop, flag: Flags, one_shot: bool, fd: bun.FileDescriptor) JSC.Maybe(void) {
        const watcher_fd = loop.fd;

        log("register: {s} ({d})", .{ @tagName(flag), fd });

        std.debug.assert(fd != invalid_fd);

        if (one_shot) {
            this.flags.insert(.one_shot);
        }

        if (comptime Environment.isLinux) {
            const one_shot_flag: u32 = if (!this.flags.contains(.one_shot)) 0 else linux.EPOLL.ONESHOT;

            const flags: u32 = switch (flag) {
                .process,
                .readable,
                => linux.EPOLL.IN | linux.EPOLL.HUP | one_shot_flag,
                .writable => linux.EPOLL.OUT | linux.EPOLL.HUP | linux.EPOLL.ERR | one_shot_flag,
                else => unreachable,
            };

            var event = linux.epoll_event{ .events = flags, .data = .{ .u64 = @intFromPtr(Pollable.init(this).ptr()) } };

            const op: u32 = if (this.isRegistered() or this.flags.contains(.needs_rearm)) linux.EPOLL.CTL_MOD else linux.EPOLL.CTL_ADD;

            const ctl = linux.epoll_ctl(
                watcher_fd,
                op,
                fd.cast(),
                &event,
            );
            this.flags.insert(.was_ever_registered);
            if (JSC.Maybe(void).errnoSys(ctl, .epoll_ctl)) |errno| {
                this.deactivate(loop);
                return errno;
            }
        } else if (comptime Environment.isMac) {
            var changelist = std.mem.zeroes([2]std.os.system.kevent64_s);
            const one_shot_flag: u16 = if (!this.flags.contains(.one_shot)) 0 else std.c.EV_ONESHOT;
            changelist[0] = switch (flag) {
                .readable => .{
                    .ident = @intCast(fd.cast()),
                    .filter = std.os.system.EVFILT_READ,
                    .data = 0,
                    .fflags = 0,
                    .udata = @intFromPtr(Pollable.init(this).ptr()),
                    .flags = std.c.EV_ADD | one_shot_flag,
                    .ext = .{ this.generation_number, 0 },
                },
                .writable => .{
                    .ident = @intCast(fd.cast()),
                    .filter = std.os.system.EVFILT_WRITE,
                    .data = 0,
                    .fflags = 0,
                    .udata = @intFromPtr(Pollable.init(this).ptr()),
                    .flags = std.c.EV_ADD | one_shot_flag,
                    .ext = .{ this.generation_number, 0 },
                },
                .process => .{
                    .ident = @intCast(fd.cast()),
                    .filter = std.os.system.EVFILT_PROC,
                    .data = 0,
                    .fflags = std.c.NOTE_EXIT,
                    .udata = @intFromPtr(Pollable.init(this).ptr()),
                    .flags = std.c.EV_ADD | one_shot_flag,
                    .ext = .{ this.generation_number, 0 },
                },
                .machport => .{
                    .ident = @intCast(fd.cast()),
                    .filter = std.os.system.EVFILT_MACHPORT,
                    .data = 0,
                    .fflags = 0,
                    .udata = @intFromPtr(Pollable.init(this).ptr()),
                    .flags = std.c.EV_ADD | one_shot_flag,
                    .ext = .{ this.generation_number, 0 },
                },
                else => unreachable,
            };

            // output events only include change errors
            const KEVENT_FLAG_ERROR_EVENTS = 0x000002;

            // The kevent() system call returns the number of events placed in
            // the eventlist, up to the value given by nevents.  If the time
            // limit expires, then kevent() returns 0.
            const rc = rc: {
                while (true) {
                    const rc = std.os.system.kevent64(
                        watcher_fd,
                        &changelist,
                        1,
                        // The same array may be used for the changelist and eventlist.
                        &changelist,
                        // we set 0 here so that if we get an error on
                        // registration, it becomes errno
                        0,
                        KEVENT_FLAG_ERROR_EVENTS,
                        &timeout,
                    );

                    if (std.c.getErrno(rc) == .INTR) continue;
                    break :rc rc;
                }
            };

            this.flags.insert(.was_ever_registered);

            // If an error occurs while
            // processing an element of the changelist and there is enough room
            // in the eventlist, then the event will be placed in the eventlist
            // with EV_ERROR set in flags and the system error in data.
            if (changelist[0].flags == std.c.EV_ERROR and changelist[0].data != 0) {
                return JSC.Maybe(void).errnoSys(changelist[0].data, .kevent).?;
                // Otherwise, -1 will be returned, and errno will be set to
                // indicate the error condition.
            }

            const errno = std.c.getErrno(rc);

            if (errno != .SUCCESS) {
                this.deactivate(loop);
                return JSC.Maybe(void){
                    .err = bun.sys.Error.fromCode(errno, .kqueue),
                };
            }
        } else {
            @compileError("unsupported platform");
        }
        this.activate(loop);
        this.flags.insert(switch (flag) {
            .readable => .poll_readable,
            .process => if (comptime Environment.isLinux) .poll_readable else .poll_process,
            .writable => .poll_writable,
            .machport => .poll_machport,
            else => unreachable,
        });
        this.flags.remove(.needs_rearm);

        return JSC.Maybe(void).success;
    }

    const invalid_fd = bun.invalid_fd;

    pub inline fn fileDescriptor(this: *FilePoll) bun.FileDescriptor {
        return @intCast(this.fd);
    }

    pub fn unregister(this: *FilePoll, loop: *Loop, force_unregister: bool) JSC.Maybe(void) {
        return this.unregisterWithFd(loop, this.fd, force_unregister);
    }

    pub fn unregisterWithFd(this: *FilePoll, loop: *Loop, fd: bun.FileDescriptor, force_unregister: bool) JSC.Maybe(void) {
        if (Environment.allow_assert) {
            std.debug.assert(fd.int() >= 0 and fd != bun.invalid_fd);
        }
        defer this.deactivate(loop);

        if (!(this.flags.contains(.poll_readable) or this.flags.contains(.poll_writable) or this.flags.contains(.poll_process) or this.flags.contains(.poll_machport))) {

            // no-op
            return JSC.Maybe(void).success;
        }

        std.debug.assert(fd != invalid_fd);
        const watcher_fd = loop.fd;
        const flag: Flags = brk: {
            if (this.flags.contains(.poll_readable))
                break :brk .readable;
            if (this.flags.contains(.poll_writable))
                break :brk .writable;
            if (this.flags.contains(.poll_process))
                break :brk .process;

            if (this.flags.contains(.poll_machport))
                break :brk .machport;
            return JSC.Maybe(void).success;
        };

        if (this.flags.contains(.needs_rearm) and !force_unregister) {
            log("unregister: {s} ({d}) skipped due to needs_rearm", .{ @tagName(flag), fd });
            this.flags.remove(.poll_process);
            this.flags.remove(.poll_readable);
            this.flags.remove(.poll_process);
            this.flags.remove(.poll_machport);
            return JSC.Maybe(void).success;
        }

        log("unregister: {s} ({d})", .{ @tagName(flag), fd });

        if (comptime Environment.isLinux) {
            const ctl = linux.epoll_ctl(
                watcher_fd,
                linux.EPOLL.CTL_DEL,
                fd.cast(),
                null,
            );

            if (JSC.Maybe(void).errnoSys(ctl, .epoll_ctl)) |errno| {
                return errno;
            }
        } else if (comptime Environment.isMac) {
            var changelist = std.mem.zeroes([2]std.os.system.kevent64_s);

            changelist[0] = switch (flag) {
                .readable => .{
                    .ident = @intCast(fd.cast()),
                    .filter = std.os.system.EVFILT_READ,
                    .data = 0,
                    .fflags = 0,
                    .udata = @intFromPtr(Pollable.init(this).ptr()),
                    .flags = std.c.EV_DELETE,
                    .ext = .{ 0, 0 },
                },
                .machport => .{
                    .ident = @intCast(fd.cast()),
                    .filter = std.os.system.EVFILT_MACHPORT,
                    .data = 0,
                    .fflags = 0,
                    .udata = @intFromPtr(Pollable.init(this).ptr()),
                    .flags = std.c.EV_DELETE,
                    .ext = .{ 0, 0 },
                },
                .writable => .{
                    .ident = @intCast(fd.cast()),
                    .filter = std.os.system.EVFILT_WRITE,
                    .data = 0,
                    .fflags = 0,
                    .udata = @intFromPtr(Pollable.init(this).ptr()),
                    .flags = std.c.EV_DELETE,
                    .ext = .{ 0, 0 },
                },
                .process => .{
                    .ident = @intCast(fd.cast()),
                    .filter = std.os.system.EVFILT_PROC,
                    .data = 0,
                    .fflags = std.c.NOTE_EXIT,
                    .udata = @intFromPtr(Pollable.init(this).ptr()),
                    .flags = std.c.EV_DELETE,
                    .ext = .{ 0, 0 },
                },
                else => unreachable,
            };

            // output events only include change errors
            const KEVENT_FLAG_ERROR_EVENTS = 0x000002;

            // The kevent() system call returns the number of events placed in
            // the eventlist, up to the value given by nevents.  If the time
            // limit expires, then kevent() returns 0.
            const rc = std.os.system.kevent64(
                watcher_fd,
                &changelist,
                1,
                // The same array may be used for the changelist and eventlist.
                &changelist,
                1,
                KEVENT_FLAG_ERROR_EVENTS,
                &timeout,
            );
            // If an error occurs while
            // processing an element of the changelist and there is enough room
            // in the eventlist, then the event will be placed in the eventlist
            // with EV_ERROR set in flags and the system error in data.
            if (changelist[0].flags == std.c.EV_ERROR) {
                return JSC.Maybe(void).errnoSys(changelist[0].data, .kevent).?;
                // Otherwise, -1 will be returned, and errno will be set to
                // indicate the error condition.
            }

            const errno = std.c.getErrno(rc);
            switch (rc) {
                std.math.minInt(@TypeOf(rc))...-1 => return JSC.Maybe(void).errnoSys(@intFromEnum(errno), .kevent).?,
                else => {},
            }
        } else {
            @compileError("unsupported platform");
        }

        this.flags.remove(.needs_rearm);
        this.flags.remove(.one_shot);
        // we don't support both right now
        std.debug.assert(!(this.flags.contains(.poll_readable) and this.flags.contains(.poll_writable)));
        this.flags.remove(.poll_readable);
        this.flags.remove(.poll_writable);
        this.flags.remove(.poll_process);
        this.flags.remove(.poll_machport);

        return JSC.Maybe(void).success;
    }
};

pub const Waker = bun.AsyncIO.Waker;
