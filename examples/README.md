# Examples

Small scripts to demonstrate the dropshell pattern. To run any of them:

```bash
# in one terminal:
cd ..
bash dropshell.sh

# in another:
cp examples/01-hello.sh .dropshell/queue/01-hello.sh
sleep 2
cat .dropshell/done/01-hello.out
```

Or, more realistically: an AI assistant writes scripts like these directly into the queue dir.
