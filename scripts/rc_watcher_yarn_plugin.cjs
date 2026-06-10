const fs = require('node:fs');

let isRunning = false;

module.exports = {
	name: 'rc-watcher-plugin',
	factory: require => ({
		/**
		 * @type {require('@yarnpkg/core').Hooks}
		 */
		hooks: {
			async wrapScriptExecution(executor, project, locator, scriptName, extra) {
				process.env.RC_WATCHER_DEBUG && console.log("RC WATCHER", Object.keys(project), locator, isRunning, scriptName.includes('build'));

				if (isRunning || !scriptName.includes('build') || (locator.name !== 'rocket.chat' && locator.name !== 'meteor')) {
					return executor;
				}

				isRunning = true;

				fs.writeFileSync('/tmp/rc-watcher.pipe', 'watcher#echo BUILDING');

				return () => executor().then((result) => {
					fs.writeFileSync('/tmp/rc-watcher.pipe', `watcher#echo IDLE (BUILD ${ result > 0 ? 'FAILED' : 'FINISHED' })`);
				}).catch(() => {
					fs.writeFileSync('/tmp/rc-watcher.pipe', 'watcher#echo IDLE (BUILD FAILED)');
				});
			},
		}
	})
}
