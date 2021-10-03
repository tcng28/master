from pathlib import Path
import glob
import os
import shutil

p = Path('/')
dirs = [x for x in p.iterdir() if x.is_dir()]
print("hello world")
print(dirs)

sourceFolder = "/Users/tng/Projects/Triangulum-NEW/NextGenUcp/InfraOperator/infrastructure-operator"
targetFolder = "/Users/tng/tmp/mc1"

shutil.rmtree(targetFolder)

p2 = Path(sourceFolder)
allDirs = glob.glob(sourceFolder+"/**/message-catalog", recursive=True)
for dire in allDirs:
    mcFolder = dire.replace(sourceFolder, "")
    print(mcFolder)
    print(dire)
    targetMcFolder = targetFolder+mcFolder
    print(targetMcFolder)
    shutil.copytree(dire, targetMcFolder)


print("\n\n\nLIST ALL MESSAGE CATALGO FOLDERS")
allDirs = glob.glob(targetFolder+"/**/message-catalog", recursive=True)
for dire in allDirs:
    print(dire)

print("\n\n\nDelete message_id_test.go")
allFiles = glob.glob(targetFolder+"/**/message_id_test.go", recursive=True)
for file in allFiles:
    print("deleting " + file)
    os.remove(file)

print("\n\n\nDelete message_id.go")
allFiles = glob.glob(targetFolder+"/**/message_id.go", recursive=True)
for file in allFiles:
    print("deleting " + file)
    os.remove(file)

# for root, subdirs, files in os.walk(sourceFolder):   
#     print(root)