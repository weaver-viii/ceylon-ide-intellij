import ceylon.interop.java {
    CeylonList,
    javaClass
}

import com.intellij.codeInsight.lookup {
    LookupElement
}
import com.intellij.openapi.editor {
    Document
}
import com.intellij.openapi.fileEditor {
    FileDocumentManager
}
import com.intellij.openapi.\imodule {
    Module
}
import com.intellij.openapi.util {
    TextRange
}
import com.intellij.openapi.vfs {
    VirtualFileManager,
    VirtualFile
}
import com.redhat.ceylon.compiler.typechecker.context {
    PhasedUnit
}
import com.redhat.ceylon.ide.common.completion {
    IdeCompletionManager
}
import com.redhat.ceylon.ide.common.correct {
    AbstractQuickFix,
    ImportProposals
}
import com.redhat.ceylon.ide.common.util {
    Indents
}
import com.redhat.ceylon.model.typechecker.model {
    Unit
}

import org.intellij.plugins.ceylon.ide.ceylonCode {
    ITypeCheckerProvider
}
import org.intellij.plugins.ceylon.ide.ceylonCode.completion {
    ideaCompletionManager
}
import org.intellij.plugins.ceylon.ide.ceylonCode.psi {
    CeylonFile
}
import org.intellij.plugins.ceylon.ide.ceylonCode.util {
    ideaIndents
}
import com.redhat.ceylon.ide.common.model {
    IResourceAware
}
import com.intellij.psi {
    PsiManager
}

shared interface IdeaQuickFix
        satisfies AbstractQuickFix<CeylonFile,Document,InsertEdit,TextEdit,
        TextChange,TextRange,Module,IdeaQuickFixData,LookupElement> {
    
    shared actual Integer getTextEditOffset(TextEdit change) => change.start;
    
    shared actual List<PhasedUnit> getUnits(Module mod) {
        value tc = mod.getComponent(javaClass<ITypeCheckerProvider>()).typeChecker;
        return CeylonList(tc.phasedUnits.phasedUnits);
    }
    
    shared actual Indents<Document> indents => ideaIndents;
    
    shared actual TextRange newRegion(Integer start, Integer length)
            => TextRange.from(start, length);
    
    shared actual TextChange newTextChange(String desc,
        PhasedUnit|CeylonFile|Document unitOrFile) {
        
        if (is Document unitOrFile) {
            return TextChange(unitOrFile);
        } else {
            VirtualFile? vfile = if (is PhasedUnit unitOrFile) 
                          then VirtualFileManager.instance
                            .findFileByUrl("file://" + unitOrFile.unit.fullPath)
                          else unitOrFile.virtualFile;
    
            assert (exists vfile);
            
            return TextChange(FileDocumentManager.instance.getDocument(vfile));
        }
    }
    
    shared actual IdeCompletionManager<out Anything,LookupElement,Document>
            completionManager => ideaCompletionManager;
    
    shared actual ImportProposals<out Anything,out Anything,Document,InsertEdit,
        TextEdit,TextChange> importProposals
            => ideaImportProposals;

    
    shared actual PhasedUnit? getPhasedUnit(Unit? u, IdeaQuickFixData data) {
        if (exists u,
            exists tc = data.project
                    .getComponent(javaClass<ITypeCheckerProvider>())
                    .typeChecker) {
            
            return tc.phasedUnits.getPhasedUnitFromRelativePath(u.relativePath);
        }
        return null;
    }
    
    shared actual CeylonFile? getFile<NativeFile>(IResourceAware<out Anything,out Anything,NativeFile> pu, IdeaQuickFixData data) {
        if (is VirtualFile vf = pu.resourceFile,
            is CeylonFile file = PsiManager.getInstance(data.project.project).findFile(vf)) {
            return file;
        }
        
        return null;
    }
}