import com.intellij.openapi.application {
    Result
}
import com.intellij.openapi.command {
    WriteCommandAction
}
import com.intellij.openapi.editor {
    Editor
}
import com.intellij.openapi.\imodule {
    ModuleUtil
}
import com.intellij.openapi.project {
    Project
}
import com.intellij.openapi.util {
    TextRange
}
import com.intellij.psi {
    PsiFile,
    PsiDocumentManager
}
import com.redhat.ceylon.compiler.typechecker.context {
    PhasedUnit
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree,
    Node
}
import com.redhat.ceylon.ide.common.refactoring {
    ExtractValueRefactoring
}
import com.redhat.ceylon.ide.common.util {
    nodes
}
import com.redhat.ceylon.model.typechecker.model {
    Type,
    Declaration
}

import java.lang {
    JString=String
}
import java.util {
    ArrayList,
    List
}

import org.antlr.runtime {
    CommonToken
}
import org.intellij.plugins.ceylon.ide.ceylonCode.platform {
    IdeaDocument,
    IdeaTextChange
}
import org.intellij.plugins.ceylon.ide.ceylonCode.psi {
    CeylonFile
}
import org.intellij.plugins.ceylon.ide.ceylonCode.vfs {
    VirtualFileVirtualFile
}

shared class ExtractValueHandler() extends AbstractExtractHandler() {

    shared actual [TextRange+]? extract(Project project, Editor editor, CeylonFile file, TextRange range, Tree.Declaration? scope) {
        if (exists localAnalysisResult = file.localAnalysisResult,
            exists typecheckedRootNode = localAnalysisResult.typecheckedRootNode,
            exists phasedUnit = localAnalysisResult.lastPhasedUnit) {
            assert(exists node = nodes.findNode {
                node = typecheckedRootNode;
                tokens = localAnalysisResult.tokens;
                startOffset = range.startOffset;
                endOffset = range.endOffset;
            });
            
            value refactoring = IdeaExtractValueRefactoring(file, phasedUnit, localAnalysisResult.tokens, editor, node);
            value name = nodes.nameProposals(if (is Tree.Term node) then node else null).first;
            refactoring.newName = name;
            return refactoring.extractInFile(project, file);
        }
        return null;
    }
}

class IdeaExtractValueRefactoring(CeylonFile file, PhasedUnit phasedUnit, List<CommonToken> theTokens, Editor editor, Node node)
        satisfies ExtractValueRefactoring<TextRange> {

    editorPhasedUnit => phasedUnit;

    getAllUnits() => ArrayList<PhasedUnit>();
    searchInFile(PhasedUnit pu) => false;
    searchInEditor() => false;
    rootNode => phasedUnit.compilationUnit;
    shared variable actual Boolean canBeInferred = false;
    shared actual variable Type? type = null;
    shared actual variable Boolean getter = false;

    shared variable actual String? internalNewName = "";
    shared actual variable Boolean explicitType = false;

    shared actual variable TextRange? typeRegion = null;
    shared actual variable TextRange? decRegion = null;
    shared actual variable TextRange? refRegion = null;

    inSameProject(Declaration decl) => true; // TODO
    
    dupeRegions = ArrayList<TextRange>();

    assert(exists mod = ModuleUtil.findModuleForFile(file.virtualFile, file.project));

    editorData => object satisfies EditorData {
        tokens => theTokens;
        rootNode => phasedUnit.compilationUnit;
        node => outer.node;
        sourceVirtualFile
                => VirtualFileVirtualFile(file.virtualFile, mod);
    };
    
    newRegion(Integer start, Integer length) => TextRange.from(start, length);

    shared [TextRange+]? extractInFile(Project myProject, PsiFile file) {
        value document = editor.document;
        value tfc = IdeaTextChange(IdeaDocument(document));
        build(tfc);

        return object extends WriteCommandAction<[TextRange+]?>(myProject, file) {
            shared actual void run(Result<[TextRange+]?> result) {
                tfc.apply();

                if (exists dec = decRegion, exists ref = refRegion) {
                    editor.selectionModel.setSelection(dec.startOffset, dec.endOffset);
                    value newId = document.getText(dec);
                    for (dupe in dupeRegions) {
                        document.replaceString(
                            dupe.startOffset, 
                            dupe.endOffset, 
                            JString(newId));
                    }
                    result.setResult([dec, ref, for (dupe in dupeRegions) dupe]);
                }

                PsiDocumentManager.getInstance(project).commitAllDocuments();

            }
        }.execute().resultObject;
    }
    
}
