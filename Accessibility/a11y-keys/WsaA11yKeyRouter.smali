.class final Lcom/android/server/input/WsaA11yKeyRouter;
.super Ljava/lang/Object;
.source "WsaA11yKeyRouter.java"


# static fields
.field private static final ACTION_PASS_TO_USER:I = 0x1

.field private static final FLAG_DISABLE_KEY_REPEAT:I = 0x8000000

.field private static final FLAG_FILTERED:I = 0x4000000

.field private static final FLAG_INJECTED:I = 0x1000000

.field private static final FLAG_INTERACTIVE:I = 0x20000000

.field private static final FLAG_PASS_TO_USER:I = 0x40000000

.field private static final FLAG_TRUSTED:I = 0x2000000

.field private static final FLAG_VIRTUAL:I = 0x2

.field private static final INJECT_MODE_ASYNC:I = 0x0

.field private static final NO_TARGET_UID:I = -0x1

.field private static final TAG:Ljava/lang/String; = "WsaA11yKeyRouter"

.field private static final WSA_INPUT_PACKAGE:Ljava/lang/String; = "com.microsoft.windows.userapp"

.field private static sContext:Ljava/lang/reflect/Field; = null

.field private static volatile sDisabled:Z = false

.field private static sFilterInputEvent:Ljava/lang/reflect/Method; = null

.field private static sInputFilter:Ljava/lang/reflect/Field; = null

.field private static sInterceptKeyBeforeQueueing:Ljava/lang/reflect/Method; = null

.field private static sWsaUid:I = -0x1


# direct methods
.method static constructor <clinit>()V
    .registers 0

    return-void
.end method

.method private constructor <init>()V
    .registers 1

    .line 51
    invoke-direct {p0}, Ljava/lang/Object;-><init>()V

    return-void
.end method

.method private static declared-synchronized init(Ljava/lang/Object;)Z
    .registers 12
    .annotation system Ldalvik/annotation/Throws;
        value = {
            Ljava/lang/ReflectiveOperationException;
        }
    .end annotation

    const-string v0, "Routing key events injected by uid "

    const-class v1, Lcom/android/server/input/WsaA11yKeyRouter;

    monitor-enter v1

    .line 91
    :try_start_5
    sget-object v2, Lcom/android/server/input/WsaA11yKeyRouter;->sFilterInputEvent:Ljava/lang/reflect/Method;
    :try_end_7
    .catchall {:try_start_5 .. :try_end_7} :catchall_82

    const/4 v3, 0x1

    if-eqz v2, :cond_c

    .line 92
    monitor-exit v1

    return v3

    .line 94
    :cond_c
    :try_start_c
    invoke-virtual {p0}, Ljava/lang/Object;->getClass()Ljava/lang/Class;

    move-result-object v2

    .line 95
    const-string v4, "mContext"

    invoke-virtual {v2, v4}, Ljava/lang/Class;->getDeclaredField(Ljava/lang/String;)Ljava/lang/reflect/Field;

    move-result-object v4

    .line 96
    invoke-virtual {v4, v3}, Ljava/lang/reflect/Field;->setAccessible(Z)V

    .line 97
    const-string v5, "mInputFilter"

    invoke-virtual {v2, v5}, Ljava/lang/Class;->getDeclaredField(Ljava/lang/String;)Ljava/lang/reflect/Field;

    move-result-object v5

    .line 98
    invoke-virtual {v5, v3}, Ljava/lang/reflect/Field;->setAccessible(Z)V

    .line 99
    const-string v6, "interceptKeyBeforeQueueing"

    const/4 v7, 0x2

    new-array v8, v7, [Ljava/lang/Class;

    const-class v9, Landroid/view/KeyEvent;

    const/4 v10, 0x0

    aput-object v9, v8, v10

    sget-object v9, Ljava/lang/Integer;->TYPE:Ljava/lang/Class;

    aput-object v9, v8, v3

    invoke-virtual {v2, v6, v8}, Ljava/lang/Class;->getDeclaredMethod(Ljava/lang/String;[Ljava/lang/Class;)Ljava/lang/reflect/Method;

    move-result-object v6

    .line 101
    invoke-virtual {v6, v3}, Ljava/lang/reflect/Method;->setAccessible(Z)V

    .line 102
    const-string v8, "filterInputEvent"

    new-array v7, v7, [Ljava/lang/Class;

    const-class v9, Landroid/view/InputEvent;

    aput-object v9, v7, v10

    sget-object v9, Ljava/lang/Integer;->TYPE:Ljava/lang/Class;

    aput-object v9, v7, v3

    invoke-virtual {v2, v8, v7}, Ljava/lang/Class;->getDeclaredMethod(Ljava/lang/String;[Ljava/lang/Class;)Ljava/lang/reflect/Method;

    move-result-object v2

    .line 103
    invoke-virtual {v2, v3}, Ljava/lang/reflect/Method;->setAccessible(Z)V
    :try_end_4a
    .catchall {:try_start_c .. :try_end_4a} :catchall_82

    .line 105
    :try_start_4a
    invoke-virtual {v4, p0}, Ljava/lang/reflect/Field;->get(Ljava/lang/Object;)Ljava/lang/Object;

    move-result-object p0

    check-cast p0, Landroid/content/Context;

    invoke-virtual {p0}, Landroid/content/Context;->getPackageManager()Landroid/content/pm/PackageManager;

    move-result-object p0

    const-string v7, "com.microsoft.windows.userapp"

    .line 106
    invoke-virtual {p0, v7, v10}, Landroid/content/pm/PackageManager;->getPackageUid(Ljava/lang/String;I)I

    move-result p0

    sput p0, Lcom/android/server/input/WsaA11yKeyRouter;->sWsaUid:I
    :try_end_5c
    .catch Landroid/content/pm/PackageManager$NameNotFoundException; {:try_start_4a .. :try_end_5c} :catch_5d
    .catchall {:try_start_4a .. :try_end_5c} :catchall_82

    goto :goto_60

    :catch_5d
    const/4 p0, -0x1

    .line 108
    :try_start_5e
    sput p0, Lcom/android/server/input/WsaA11yKeyRouter;->sWsaUid:I

    .line 110
    :goto_60
    sput-object v4, Lcom/android/server/input/WsaA11yKeyRouter;->sContext:Ljava/lang/reflect/Field;

    .line 111
    sput-object v5, Lcom/android/server/input/WsaA11yKeyRouter;->sInputFilter:Ljava/lang/reflect/Field;

    .line 112
    sput-object v6, Lcom/android/server/input/WsaA11yKeyRouter;->sInterceptKeyBeforeQueueing:Ljava/lang/reflect/Method;

    .line 113
    sput-object v2, Lcom/android/server/input/WsaA11yKeyRouter;->sFilterInputEvent:Ljava/lang/reflect/Method;

    .line 114
    const-string p0, "WsaA11yKeyRouter"

    sget v2, Lcom/android/server/input/WsaA11yKeyRouter;->sWsaUid:I

    new-instance v4, Ljava/lang/StringBuilder;

    invoke-direct {v4, v0}, Ljava/lang/StringBuilder;-><init>(Ljava/lang/String;)V

    invoke-virtual {v4, v2}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;

    const-string v0, " through the input filter"

    invoke-virtual {v4, v0}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    invoke-virtual {v4}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object v0

    invoke-static {p0, v0}, Landroid/util/Log;->i(Ljava/lang/String;Ljava/lang/String;)I
    :try_end_80
    .catchall {:try_start_5e .. :try_end_80} :catchall_82

    .line 115
    monitor-exit v1

    return v3

    :catchall_82
    move-exception p0

    :try_start_83
    monitor-exit v1
    :try_end_84
    .catchall {:try_start_83 .. :try_end_84} :catchall_82

    throw p0
.end method

.method static route(Ljava/lang/Object;Landroid/view/InputEvent;II)Z
    .registers 9

    .line 55
    sget-boolean v0, Lcom/android/server/input/WsaA11yKeyRouter;->sDisabled:Z

    const/4 v1, 0x0

    if-nez v0, :cond_a9

    if-nez p2, :cond_a9

    const/4 p2, -0x1

    if-ne p3, p2, :cond_a9

    instance-of p2, p1, Landroid/view/KeyEvent;

    if-nez p2, :cond_10

    goto/16 :goto_a9

    .line 59
    :cond_10
    invoke-static {}, Landroid/os/Binder;->getCallingUid()I

    move-result p2

    .line 60
    invoke-static {}, Landroid/os/Binder;->clearCallingIdentity()J

    move-result-wide v2

    const/4 p3, 0x1

    .line 62
    :try_start_19
    invoke-static {p0}, Lcom/android/server/input/WsaA11yKeyRouter;->init(Ljava/lang/Object;)Z

    move-result v0

    if-eqz v0, :cond_92

    sget v0, Lcom/android/server/input/WsaA11yKeyRouter;->sWsaUid:I

    if-ne p2, v0, :cond_92

    sget-object p2, Lcom/android/server/input/WsaA11yKeyRouter;->sInputFilter:Ljava/lang/reflect/Field;

    invoke-virtual {p2, p0}, Ljava/lang/reflect/Field;->get(Ljava/lang/Object;)Ljava/lang/Object;

    move-result-object p2

    if-nez p2, :cond_2c

    goto :goto_92

    .line 66
    :cond_2c
    new-instance p2, Landroid/view/KeyEvent;

    check-cast p1, Landroid/view/KeyEvent;

    invoke-direct {p2, p1}, Landroid/view/KeyEvent;-><init>(Landroid/view/KeyEvent;)V

    .line 68
    invoke-virtual {p2}, Landroid/view/KeyEvent;->getFlags()I

    move-result p1

    and-int/lit8 p1, p1, 0x40

    if-eqz p1, :cond_3f

    const p1, 0xb000002

    goto :goto_41

    :cond_3f
    const/high16 p1, 0xb000000

    .line 71
    :goto_41
    sget-object v0, Lcom/android/server/input/WsaA11yKeyRouter;->sContext:Ljava/lang/reflect/Field;

    invoke-virtual {v0, p0}, Ljava/lang/reflect/Field;->get(Ljava/lang/Object;)Ljava/lang/Object;

    move-result-object v0

    check-cast v0, Landroid/content/Context;

    const-class v4, Landroid/os/PowerManager;

    invoke-virtual {v0, v4}, Landroid/content/Context;->getSystemService(Ljava/lang/Class;)Ljava/lang/Object;

    move-result-object v0

    check-cast v0, Landroid/os/PowerManager;

    if-eqz v0, :cond_59

    .line 72
    invoke-virtual {v0}, Landroid/os/PowerManager;->isInteractive()Z

    move-result v0

    if-eqz v0, :cond_5c

    :cond_59
    const/high16 v0, 0x20000000

    or-int/2addr p1, v0

    .line 75
    :cond_5c
    sget-object v0, Lcom/android/server/input/WsaA11yKeyRouter;->sInterceptKeyBeforeQueueing:Ljava/lang/reflect/Method;

    invoke-static {p1}, Ljava/lang/Integer;->valueOf(I)Ljava/lang/Integer;

    move-result-object v4

    filled-new-array {p2, v4}, [Ljava/lang/Object;

    move-result-object v4

    invoke-virtual {v0, p0, v4}, Ljava/lang/reflect/Method;->invoke(Ljava/lang/Object;[Ljava/lang/Object;)Ljava/lang/Object;

    move-result-object v0

    check-cast v0, Ljava/lang/Integer;

    invoke-virtual {v0}, Ljava/lang/Integer;->intValue()I

    move-result v0

    and-int/2addr v0, p3

    if-eqz v0, :cond_76

    const/high16 v0, 0x40000000    # 2.0f

    or-int/2addr p1, v0

    .line 80
    :cond_76
    sget-object v0, Lcom/android/server/input/WsaA11yKeyRouter;->sFilterInputEvent:Ljava/lang/reflect/Method;

    const/high16 v4, 0x4000000

    or-int/2addr p1, v4

    invoke-static {p1}, Ljava/lang/Integer;->valueOf(I)Ljava/lang/Integer;

    move-result-object p1

    filled-new-array {p2, p1}, [Ljava/lang/Object;

    move-result-object p1

    invoke-virtual {v0, p0, p1}, Ljava/lang/reflect/Method;->invoke(Ljava/lang/Object;[Ljava/lang/Object;)Ljava/lang/Object;

    move-result-object p0

    check-cast p0, Ljava/lang/Boolean;

    invoke-virtual {p0}, Ljava/lang/Boolean;->booleanValue()Z

    move-result p0
    :try_end_8d
    .catchall {:try_start_19 .. :try_end_8d} :catchall_96

    xor-int/2addr p0, p3

    .line 86
    invoke-static {v2, v3}, Landroid/os/Binder;->restoreCallingIdentity(J)V

    return p0

    :cond_92
    :goto_92
    invoke-static {v2, v3}, Landroid/os/Binder;->restoreCallingIdentity(J)V

    return v1

    :catchall_96
    move-exception p0

    .line 82
    :try_start_97
    sput-boolean p3, Lcom/android/server/input/WsaA11yKeyRouter;->sDisabled:Z

    .line 83
    const-string p1, "WsaA11yKeyRouter"

    const-string p2, "Disabled after error"

    invoke-static {p1, p2, p0}, Landroid/util/Log;->e(Ljava/lang/String;Ljava/lang/String;Ljava/lang/Throwable;)I
    :try_end_a0
    .catchall {:try_start_97 .. :try_end_a0} :catchall_a4

    .line 86
    invoke-static {v2, v3}, Landroid/os/Binder;->restoreCallingIdentity(J)V

    return v1

    :catchall_a4
    move-exception p0

    invoke-static {v2, v3}, Landroid/os/Binder;->restoreCallingIdentity(J)V

    .line 87
    throw p0

    :cond_a9
    :goto_a9
    return v1
.end method
