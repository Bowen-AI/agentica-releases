"""Exercise the actual curl-pipe installer with isolated files and fake services.

No writes to HOME, no model downloads, no app launches. Run: python3 -m unittest
 discover -s scripts -p 'test_*.py' -v
"""
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]

DISPATCH = r'''
import os, sys, shutil
from pathlib import Path
args=sys.argv[1:]; name=Path(sys.argv[0]).name
root=Path(os.environ['MOCK_ROOT'])
with (root/'calls').open('a') as log: log.write(name+' '+' '.join(args)+'\n')
if name=='uname': print(os.environ.get('MOCK_OS','Darwin') if args==['-s'] else os.environ.get('MOCK_ARCH','arm64'))
elif name=='df': print('Filesystem 1024-blocks Used Available Capacity Mounted on\nmock 999999999 0 '+os.environ.get('MOCK_SPACE','999999999')+' 0% /')
elif name=='curl':
 url=next((a for a in args if a.startswith('http')), '')
 if '/api/tags' in url: print('{"models":[]}')
 elif '-w' in args: print('https://github.com/Bowen-AI/agentica-releases/releases/tag/v0.4.0',end='')
 elif os.environ.get('MOCK_DOWNLOAD_FAIL')=='1': sys.exit(22)
 elif 'SHA256SUMS' in url:
  if os.environ.get('MOCK_CHECKSUM_MISSING')=='1': sys.exit(22)
  shutil.copy(root/'SHA256SUMS',args[args.index('-o')+1])
 else: shutil.copy(root/'archive',args[args.index('-o')+1])
elif name=='ditto': shutil.copytree(root/'payload',Path(args[-1])/'Agentica.app')
elif name=='ollama':
 if args==['list']: print('NAME ID SIZE MODIFIED\n'+os.environ.get('MOCK_INSTALLED','qwen3.5:27b')+' fake 1GB now')
 elif args[0]=='pull' and os.environ.get('MOCK_PULL_FAIL')=='1': sys.exit(1)
elif name=='llama-server':
 if os.environ.get('MOCK_LLAMA_FAIL')=='1': sys.exit(1)
 print('version test')
elif name=='ldd': print('libgood.so => /lib/libgood.so' if not os.environ.get('MOCK_LIB_MISSING') else 'libmissing.so => not found')
elif name=='sysctl': print('0')
'''


class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='agentica-installer-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        commands = self.root/'commands'; commands.mkdir()
        for name in ['curl','uname','df','ditto','ollama','llama-server','ldd','osascript','xattr','open','sysctl']:
            p=commands/name; p.write_text(f'#!{sys.executable}\n'+DISPATCH); p.chmod(0o755)
        for name in ['mktemp','awk','sed','tar','chmod','mkdir','cp','mv','tr','shasum','sha256sum','dirname','rm','date','grep','sleep','cat']:
            binary=shutil.which(name)
            if binary: (commands/name).symlink_to(binary)
        self.env={**os.environ,'PATH':str(commands),'MOCK_ROOT':str(self.root),
                  'AGENTICA_APPS_DIR':str(self.root/'Applications'),
                  'AGENTICA_INSTALL_DIR':str(self.root/'data/app'),
                  'AGENTICA_BIN_DIR':str(self.root/'bin'),
                  'OLLAMA_MODELS':str(self.root/'models'),
                  'AGENTICA_SKIP_OPEN':'1','AGENTICA_NO_MODIFY_PATH':'1'}
        # Avoid inheriting a user's model/runtime overrides into the test.
        for name in ['AGENTICA_VERSION','AGENTICA_URL','AGENTICA_SHA256','AGENTICA_MODEL','AGENTICA_ENGINE','AGENTICA_LLAMA_SERVER','AGENTICA_SKIP_MODEL']:
            self.env.pop(name,None)
        self.payload=self.root/'payload'; self.payload.mkdir()
        self.package()

    def package(self, linux=False, backend=True, valid=True):
        if linux:
            self.env.update(MOCK_OS='Linux',MOCK_ARCH='x86_64')
            backend_path=self.payload/'resources/resources/agentica-core'
            exe=self.payload/'agentica'; exe.write_text('#!/bin/sh\nexit 0\n'); exe.chmod(0o755)
        else: backend_path=self.payload/'Contents/Resources/resources/agentica-core'
        if backend:
            backend_path.parent.mkdir(parents=True,exist_ok=True)
            backend_path.write_text('#!/bin/sh\nexit '+('0' if valid else '2')+'\n'); backend_path.chmod(0o755)
        elif backend_path.exists(): backend_path.unlink()
        with tarfile.open(self.root/'archive','w:gz') as archive: archive.add(self.payload,arcname='Agentica' if linux else 'Agentica.app')
        digest=hashlib.sha256((self.root/'archive').read_bytes()).hexdigest()
        asset='Agentica-linux-x64.tar.gz' if linux else 'Agentica-mac-arm64.zip'
        (self.root/'SHA256SUMS').write_text(f'{digest}  {asset}\n')

    def run_installer(self, ok=True):
        result=subprocess.run(['/bin/bash'],input=(ROOT/'install.sh').read_text(),text=True,env=self.env,capture_output=True,timeout=15)
        if ok: self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        else: self.assertNotEqual(result.returncode,0,result.stdout+result.stderr)
        return result.stdout+result.stderr

    def calls(self): return (self.root/'calls').read_text()

    def test_mac_install_from_stdin_and_exact_model_tag(self):
        self.run_installer()
        self.assertTrue((self.root/'Applications/Agentica.app').is_dir())
        self.assertTrue((self.root/'bin/agentica').is_file())
        self.assertIn('ollama pull qwen3.5:4b-mlx',self.calls())
        self.assertNotIn('open ',self.calls())

    def test_linux_upgrade_preserves_data_and_previous_app(self):
        self.package(linux=True)
        data=self.root/'data'; data.mkdir(); (data/'history.db').write_text('important')
        app=data/'app';app.mkdir();(app/'old').write_text('rollback');(app/'agentica').write_text('old executable')
        self.run_installer()
        self.assertEqual((data/'history.db').read_text(),'important')
        self.assertEqual(next(data.glob('app.previous-*/old')).read_text(),'rollback')
        self.assertIn('ollama pull qwen3.5:4b',self.calls())
        self.assertNotIn('AppImage',self.calls())

    def test_checksum_mismatch_preserves_existing_app(self):
        app=self.root/'Applications/Agentica.app';app.mkdir(parents=True);(app/'old').write_text('keep')
        self.env['AGENTICA_SHA256']='0'*64
        self.assertIn('checksum mismatch',self.run_installer(False))
        self.assertEqual((app/'old').read_text(),'keep')

    def test_missing_checksum_fails_closed(self):
        self.env['MOCK_CHECKSUM_MISSING']='1'
        self.assertIn('checksum missing',self.run_installer(False))

    def test_incomplete_backend_rejected(self):
        self.package(backend=False)
        self.assertIn('missing its bundled backend',self.run_installer(False))

    def test_backend_dependency_failure_rejected(self):
        self.package(valid=False)
        self.assertIn('runtime validation failed',self.run_installer(False))

    def test_disk_guard_runs_before_download(self):
        self.env['MOCK_SPACE']='1'
        self.assertIn('free',self.run_installer(False))
        self.assertNotIn('Agentica-mac-arm64.zip',self.calls())

    def test_missing_curl_is_actionable(self):
        (self.root/'commands/curl').unlink()
        self.assertIn('Missing dependency: curl',self.run_installer(False))

    def test_unsupported_platform_rejected(self):
        self.env['MOCK_ARCH']='x86_64'
        self.assertIn('No supported release',self.run_installer(False))

    def test_download_failure_does_not_install(self):
        self.env['MOCK_DOWNLOAD_FAIL']='1'
        self.assertIn('Download failed',self.run_installer(False))
        self.assertFalse((self.root/'Applications/Agentica.app').exists())

    def test_linux_shared_libraries_checked(self):
        self.package(linux=True);self.env['MOCK_LIB_MISSING']='1'
        self.assertIn('libmissing.so',self.run_installer(False))

    def test_pull_failure_does_not_replace_app(self):
        self.env['MOCK_PULL_FAIL']='1'
        self.assertIn('Model download failed',self.run_installer(False))
        self.assertFalse((self.root/'Applications/Agentica.app').exists())

    def test_exact_installed_model_is_reused(self):
        self.env['MOCK_INSTALLED']='qwen3.5:4b-mlx'
        self.run_installer()
        self.assertNotIn('ollama pull',self.calls())

    def test_skip_model_does_not_claim_ready(self):
        self.env['AGENTICA_SKIP_MODEL']='1'
        self.assertIn('Model download skipped',self.run_installer())
        self.assertNotIn('ollama pull',self.calls())

    def test_llama_runtime_checks_without_ollama_download(self):
        self.env['AGENTICA_ENGINE']='llamacpp'
        self.run_installer()
        self.assertIn('llama-server --version',self.calls())
        self.assertNotIn('ollama ',self.calls())

    def test_broken_llama_runtime_rejected(self):
        self.env.update(AGENTICA_ENGINE='llamacpp',MOCK_LLAMA_FAIL='1')
        self.assertIn('llama-server cannot start',self.run_installer(False))

    def test_arbitrary_data_directory_is_not_replaced(self):
        self.package(linux=True)
        data=self.root/'data/app'; data.mkdir(parents=True)
        (data/'important.db').write_text('keep')
        self.assertIn('not an Agentica app',self.run_installer(False))
        self.assertEqual((data/'important.db').read_text(),'keep')

    def test_missing_model_tag_latest_is_canonicalized(self):
        self.env.update(AGENTICA_MODEL='custom-model',MOCK_INSTALLED='custom-model:latest')
        self.run_installer()
        self.assertNotIn('ollama pull',self.calls())

    def test_installer_copies_match(self):
        self.assertEqual((ROOT/'install.sh').read_bytes(),(ROOT/'docs/install.sh').read_bytes())

if __name__=='__main__': unittest.main()
