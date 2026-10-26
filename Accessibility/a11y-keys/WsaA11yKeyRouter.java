package com.android.server.input;

import android.content.Context;
import android.content.pm.PackageManager;
import android.os.Binder;
import android.os.PowerManager;
import android.util.Log;
import android.view.InputEvent;
import android.view.KeyEvent;

import java.lang.reflect.Field;
import java.lang.reflect.Method;

/**
 * WSA fix: keys typed in Windows reach Android through InputManager.injectInputEvent()
 * (UserInputRedirectionHandler in com.microsoft.windows.userapp). Injected events never
 * pass through the input filter, so accessibility services that filter key events
 * (TalkBack, Jieshuo, ...) only see the few keys WSA sends through its evdev keyboard.
 *
 * Called first thing in InputManagerService.injectInputEventToTarget(). It acts only for async,
 * untargeted key events from the WSA input app's uid (which holds INJECT_EVENTS) while an input
 * filter is installed: it does what InputDispatcher::notifyKey does for a hardware key (policy,
 * then filter) and returns true; the filter re-injects the event with FLAG_FILTERED when no
 * service consumes it. Otherwise it returns false and the method runs unchanged.
 */
final class WsaA11yKeyRouter {
    private static final String TAG = "WsaA11yKeyRouter";
    private static final String WSA_INPUT_PACKAGE = "com.microsoft.windows.userapp";

    // WindowManagerPolicyConstants
    private static final int FLAG_VIRTUAL = 0x00000002;
    private static final int FLAG_INJECTED = 0x01000000;
    private static final int FLAG_TRUSTED = 0x02000000;
    private static final int FLAG_FILTERED = 0x04000000;
    private static final int FLAG_DISABLE_KEY_REPEAT = 0x08000000;
    private static final int FLAG_INTERACTIVE = 0x20000000;
    private static final int FLAG_PASS_TO_USER = 0x40000000;
    // WindowManagerPolicy.ACTION_PASS_TO_USER
    private static final int ACTION_PASS_TO_USER = 0x00000001;

    private static final int INJECT_MODE_ASYNC = 0;
    private static final int NO_TARGET_UID = -1;

    private static volatile boolean sDisabled;
    private static int sWsaUid = -1;
    private static Field sContext;
    private static Field sInputFilter;
    private static Method sInterceptKeyBeforeQueueing;
    private static Method sFilterInputEvent;

    private WsaA11yKeyRouter() {
    }

    static boolean route(Object ims, InputEvent event, int mode, int targetUid) {
        if (sDisabled || mode != INJECT_MODE_ASYNC || targetUid != NO_TARGET_UID
                || !(event instanceof KeyEvent)) {
            return false;
        }
        final int callingUid = Binder.getCallingUid();
        final long ident = Binder.clearCallingIdentity();
        try {
            if (!init(ims) || callingUid != sWsaUid || sInputFilter.get(ims) == null) {
                return false;
            }
            // The filter handles the event asynchronously and recycles it: give it a copy.
            final KeyEvent key = new KeyEvent((KeyEvent) event);
            int policyFlags = FLAG_DISABLE_KEY_REPEAT | FLAG_INJECTED | FLAG_TRUSTED;
            if ((key.getFlags() & KeyEvent.FLAG_VIRTUAL_HARD_KEY) != 0) {
                policyFlags |= FLAG_VIRTUAL;
            }
            final PowerManager pm = ((Context) sContext.get(ims)).getSystemService(PowerManager.class);
            if (pm == null || pm.isInteractive()) {
                policyFlags |= FLAG_INTERACTIVE;
            }
            final int actions = (Integer) sInterceptKeyBeforeQueueing.invoke(ims, key, policyFlags);
            if ((actions & ACTION_PASS_TO_USER) != 0) {
                policyFlags |= FLAG_PASS_TO_USER;
            }
            // filterInputEvent returns true when no filter is installed (it recycled our copy).
            return !(Boolean) sFilterInputEvent.invoke(ims, key, policyFlags | FLAG_FILTERED);
        } catch (Throwable t) {
            sDisabled = true;
            Log.e(TAG, "Disabled after error", t);
            return false;
        } finally {
            Binder.restoreCallingIdentity(ident);
        }
    }

    private static synchronized boolean init(Object ims) throws ReflectiveOperationException {
        if (sFilterInputEvent != null) {
            return true;
        }
        final Class<?> c = ims.getClass();
        final Field context = c.getDeclaredField("mContext");
        context.setAccessible(true);
        final Field inputFilter = c.getDeclaredField("mInputFilter");
        inputFilter.setAccessible(true);
        final Method intercept = c.getDeclaredMethod("interceptKeyBeforeQueueing",
                KeyEvent.class, int.class);
        intercept.setAccessible(true);
        final Method filter = c.getDeclaredMethod("filterInputEvent", InputEvent.class, int.class);
        filter.setAccessible(true);
        try {
            sWsaUid = ((Context) context.get(ims)).getPackageManager()
                    .getPackageUid(WSA_INPUT_PACKAGE, 0);
        } catch (PackageManager.NameNotFoundException e) {
            sWsaUid = -1;
        }
        sContext = context;
        sInputFilter = inputFilter;
        sInterceptKeyBeforeQueueing = intercept;
        sFilterInputEvent = filter;
        Log.i(TAG, "Routing key events injected by uid " + sWsaUid + " through the input filter");
        return true;
    }
}
