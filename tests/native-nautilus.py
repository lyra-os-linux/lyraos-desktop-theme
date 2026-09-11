"""Real Nautilus in private D-Bus, XDG directories, compositor and module mount."""
from pathlib import Path
import argparse, json, os, shutil, signal, subprocess, sys, tempfile, time
import gi
gi.require_version('GdkPixbuf','2.0')
from gi.repository import GdkPixbuf, Gio, GLib

ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('--output',type=Path,required=True)
parser.add_argument('--inside',action='store_true')
parser.add_argument('--scale',type=int,default=1,choices=[1,2])
parser.add_argument('--rpm',type=Path,help='Validate the actual RPM payload instead of recompiling the production module')
args=parser.parse_args()
out=args.output.resolve();out.mkdir(parents=True,exist_ok=True)
def run(cmd,**kw):return subprocess.check_output(cmd,**kw)
if not args.inside:
    for name in ['request','reply','result.json']:(out/name).unlink(missing_ok=True)
    with tempfile.TemporaryDirectory(prefix='lyra-nautilus-') as temporary:
        tmp=Path(temporary);env=os.environ.copy()
        for key in ['DISPLAY','WAYLAND_DISPLAY','DBUS_SESSION_BUS_ADDRESS','DBUS_SYSTEM_BUS_ADDRESS','SESSION_MANAGER','XDG_SESSION_ID']:
            env.pop(key,None)
        for key,sub in [('XDG_RUNTIME_DIR','run'),('XDG_CONFIG_HOME','config'),('XDG_DATA_HOME','data'),('XDG_CACHE_HOME','cache'),('XDG_STATE_HOME','state')]:
            (tmp/sub).mkdir(mode=0o700);env[key]=str(tmp/sub)
        env.update(LYRA_NATIVE_ROOT=str(tmp),LYRA_NATIVE_PROBE=str(out),GSETTINGS_BACKEND='keyfile',
            XDG_CURRENT_DESKTOP='GNOME',XDG_SESSION_TYPE='wayland',GDK_BACKEND='wayland',GDK_SCALE=str(args.scale),
            G_MESSAGES_DEBUG='lyra-watermark',GTK_A11Y='none',GIO_USE_VFS='local',GVFS_DISABLE_FUSE='1',LIBGL_ALWAYS_SOFTWARE='1',LP_NUM_THREADS='2',GSK_RENDERER='cairo')
        modules=tmp/'modules';modules.mkdir()
        flags=run(['pkg-config','--cflags','--libs','libadwaita-1','gmodule-2.0']).decode().split()
        for source,name in [(ROOT/'src/nautilus/lyra-watermark.c','liblyra-watermark.so'),(ROOT/'tests/nautilus-probe.c','libtest-probe.so')]:
            if args.rpm and name=='liblyra-watermark.so':continue
            subprocess.run(['cc','-Wall','-Wextra','-Werror','-shared','-fPIC',str(source),'-o',str(modules/name),*flags],check=True)
        assets=tmp/'assets/nautilus';assets.mkdir(parents=True)
        shutil.copy2(ROOT/'src/nautilus/watermark-symbolic.svg',assets)
        if args.rpm:
            payload=tmp/'rpm';payload.mkdir()
            run(['cpio','-idm','--quiet'],cwd=payload,input=run(['rpm2cpio',str(args.rpm.resolve())]))
            libraries=list(payload.glob('usr/lib*/nautilus/extensions-4/liblyra-watermark.so'))
            assert len(libraries)==1
            shutil.copy2(libraries[0],modules/'liblyra-watermark.so')
            asset=payload/'usr/share/lyra-os-theme/nautilus/watermark-symbolic.svg'
            assert asset.read_bytes()==(assets/asset.name).read_bytes()
            shutil.copy2(asset,assets)
        for folder in ['empty','full']:(tmp/folder).mkdir()
        for i in range(180):(tmp/'full'/f'File {i:03d}.txt').write_text('Fixture\n')
        gtk=tmp/'config/gtk-4.0';gtk.mkdir()
        (gtk/'gtk.css').write_text('/* User stylesheet: must remain byte-identical. */\nwindow.nautilus-window.suppress-lyra scrolledwindow { background-image: none; }\n')
        (gtk/'settings.ini').write_text('[Settings]\ngtk-cursor-blink=false\ngtk-enable-animations=false\n')
        subprocess.run(['gsettings','set','org.gnome.shell','enabled-extensions','[]'],env=env,check=True)
        subprocess.run(['gsettings','set','org.gnome.desktop.interface','enable-animations','false'],env=env,check=True)
        (tmp/'session.conf').write_text('<busconfig><type>session</type><listen>unix:tmpdir=/tmp</listen><auth>EXTERNAL</auth><policy context="default"><allow send_destination="*"/><allow receive_sender="*"/><allow own="*"/></policy></busconfig>')
        with (out/'session.log').open('w') as log:
            p=subprocess.Popen(['dbus-run-session','--config-file='+str(tmp/'session.conf'),'--',sys.executable,str(Path(__file__).resolve()),'--inside','--output',str(out),'--scale',str(args.scale)],env=env,stdout=log,stderr=log,start_new_session=True)
            try:code=p.wait(timeout=150)
            finally:
                try:os.killpg(p.pid,signal.SIGTERM)
                except ProcessLookupError:pass
        if (out/'result.json').exists():
            report=json.loads((out/'result.json').read_text())
            print(json.dumps(dict(passed=report['passed'],scale=args.scale,checks=len(report.get('checks',[])))))
        else:
            print((out/'session.log').read_text()[-6000:])
        sys.exit(code)

tmp=Path(os.environ['LYRA_NATIVE_ROOT']);assert str(tmp).startswith('/tmp/lyra-nautilus-')
env=os.environ.copy();env['WAYLAND_DISPLAY']='lyra-watermark-test'
def request(command):
    (out/'reply').unlink(missing_ok=True)
    (out/'request.tmp').write_text(command)
    (out/'request.tmp').replace(out/'request')
    deadline=time.monotonic()+15
    while time.monotonic()<deadline:
        if (out/'reply').exists():return (out/'reply').read_text()
        time.sleep(.1)
    raise TimeoutError(command)
def capture(name):
    time.sleep(.5)
    assert request('capture '+str(out/(name+'.png')))=='ok'
def settings(key,value,schema='org.gnome.shell'):
    subprocess.run(['gsettings','set',schema,key,value],env=env,check=True)
def enabled(value):settings('enabled-extensions',"['sheliak@lyraos.com.br']" if value else '[]')
def pixels(name):
    p=GdkPixbuf.Pixbuf.new_from_file(str(out/(name+'.png')))
    return p,p.get_pixels()
checks=[]
def compare(name,visible=True):
    enabled(False);capture(name+'-off')
    state=json.loads(request('state'));picks=request('picks')
    enabled(True);capture(name)
    assert state==json.loads(request('state')), 'Branding changed view geometry, scroll or selection'
    assert picks==request('picks'), 'Branding changed pointer targets'
    a,ap=pixels(name+'-off');b,bp=pixels(name)
    assert (a.get_width(),a.get_height(),a.get_n_channels())==(b.get_width(),b.get_height(),b.get_n_channels())
    changed=[(i%a.get_rowstride()//a.get_n_channels(),i//a.get_rowstride(),abs(x-y)) for i,(x,y) in enumerate(zip(ap,bp)) if x!=y]
    if visible:
        assert len(changed)>100, (name,'watermark missing')
        bbox=[min(x for x,y,z in changed),min(y for x,y,z in changed),max(x for x,y,z in changed),max(y for x,y,z in changed)]
        right=state['x']+state['width'];bottom=state['y']+state['height']
        assert right-120<=bbox[0]<=bbox[2]<right-24 and bottom-120<=bbox[1]<=bbox[3]<bottom-24,(name,state,bbox)
        assert max(z for x,y,z in changed)<=24,(name,'opacity too high')
    else:
        assert not changed,(name,'watermark should be absent')
        bbox=None
    checks.append(dict(name=name,bbox=bbox,changed=len(changed),state=state,pointer_targets_unchanged=True))
    (out/'checks.json').write_text(json.dumps(checks,indent=2))
with (out/'mutter.log').open('w') as log:
    compositor=subprocess.Popen(['mutter','--headless','--wayland','--no-x11','--virtual-monitor',f'{1280*args.scale}x{900*args.scale}','--wayland-display',env['WAYLAND_DISPLAY']],env=env,stdout=log,stderr=log)
    app=None
    try:
        for _ in range(100):
            if (Path(env['XDG_RUNTIME_DIR'])/env['WAYLAND_DISPLAY']).exists():break
            if compositor.poll() is not None:raise RuntimeError('Mutter exited')
            time.sleep(.1)
        if args.scale==2:
            bus=Gio.bus_get_sync(Gio.BusType.SESSION,None)
            def display_call(method,parameters=None):
                return bus.call_sync('org.gnome.Mutter.DisplayConfig','/org/gnome/Mutter/DisplayConfig',
                    'org.gnome.Mutter.DisplayConfig',method,parameters,None,Gio.DBusCallFlags.NONE,5000,None)
            for attempt in range(50):
                try:
                    serial,monitors,logical,props=display_call('GetCurrentState').unpack()
                    break
                except GLib.Error:
                    if attempt==49 or compositor.poll() is not None:raise
                    time.sleep(.1)
            connector=monitors[0][0][0]
            mode=next(m for m in monitors[0][1] if m[6].get('is-current'))
            display_call('ApplyMonitorsConfig',GLib.Variant('(uua(iiduba(ssa{sv}))a{sv})',
                (serial,1,[(0,0,2.0,0,True,[(connector,mode[0],{})])],{})))
        with (out/'nautilus.log').open('w') as app_log:
            app=subprocess.Popen(['bwrap','--ro-bind','/','/','--dev-bind','/dev','/dev',
                '--bind',str(tmp),str(tmp),'--bind',str(out),str(out),
                '--ro-bind',str(tmp/'modules'),'/usr/lib64/nautilus/extensions-4',
                '--ro-bind',str(tmp/'assets'),'/usr/share/lyra-os-theme',
                '--die-with-parent','nautilus','--new-window',str(tmp/'empty')],env=env,stdout=app_log,stderr=app_log)
            time.sleep(2)
            (out/'widgets.txt').write_text(request('dump'))
            user_css=(tmp/'config/gtk-4.0/gtk.css').read_bytes()
            capture('startup-vanilla')
            states=[]
            for folder in ['empty','full']:
                assert request('location '+str(tmp/folder))=='ok'
                time.sleep(1)
                for mode in ['grid','list']:
                    assert request('mode '+mode)=='ok'
                    time.sleep(.5)
                    state=json.loads(request('state'));states.append(state)
                    assert state['mode']==mode and state['items']==(180 if folder=='full' else 0),state
                    for theme in ['light','dark']:
                        assert request(theme)=='ok';compare(f'{theme}-{folder}-{mode}')
                    if folder=='full':
                        assert request('scroll bottom')=='ok';time.sleep(1.5);compare(f'dark-full-{mode}-bottom')
                        assert json.loads(request('state'))['scroll']>0
                        assert request('action view.select-all')=='ok'
                        time.sleep(.5)
                        assert json.loads(request('state'))['selected']==180
                        compare(f'dark-full-{mode}-selected')
            assert request('search File 179')=='ok'
            for _ in range(40):
                if json.loads(request('state'))['items']==1:break
                time.sleep(.2)
            assert json.loads(request('state'))['items']==1
            time.sleep(1)
            compare('search')
            assert request('location '+str(tmp/'empty'))=='ok';time.sleep(.5)
            assert request('resize 1050 700')=='ok';time.sleep(.5)
            compare('resized')
            assert json.loads(request('state'))['scale']==args.scale
            assert request('custom-on')=='ok';compare('user-css',False)
            assert request('custom-off')=='ok';compare('user-css-restored')
            for key,value,reset in [('disabled-extensions',"['sheliak@lyraos.com.br']",'[]'),('disable-user-extensions','true','false')]:
                settings(key,value);compare(key,False)
                settings(key,reset);compare(key+'-restored')
            settings('high-contrast','true','org.gnome.desktop.a11y.interface');compare('high-contrast',False)
            settings('high-contrast','false','org.gnome.desktop.a11y.interface');compare('contrast-restored')
            assert request('action win.new-tab')=='ok';time.sleep(.5)
            assert request('location '+str(tmp/'full'))=='ok';time.sleep(1)
            compare('second-tab')
            assert request('tab 0')=='ok';time.sleep(.5)
            assert json.loads(request('state'))['items']==0
            compare('first-tab-restored')
            assert request('action app.clone-window')=='ok';time.sleep(.5)
            assert json.loads(request('state'))['windows']==2
            assert request('window 0')=='ok';first=json.loads(request('state'))['window']
            assert request('window 1')=='ok'
            assert json.loads(request('state'))['window']!=first
            compare('second-window')
            assert (tmp/'config/gtk-4.0/gtk.css').read_bytes()==user_css
            app_log.flush()
            diagnostics=(out/'nautilus.log').read_text()
            assert not any(text in diagnostics for text in ['Theme parser error','Gtk-CRITICAL','Gtk-ERROR','GLib-GObject-CRITICAL']),diagnostics
            (out/'result.json').write_text(json.dumps({'passed':True,'scale':args.scale,'checks':checks},indent=2))
    finally:
        if app:
            app.terminate()
            try:app.wait(timeout=5)
            except subprocess.TimeoutExpired:app.kill();app.wait()
        compositor.terminate()
        try:compositor.wait(timeout=5)
        except subprocess.TimeoutExpired:compositor.kill();compositor.wait()
