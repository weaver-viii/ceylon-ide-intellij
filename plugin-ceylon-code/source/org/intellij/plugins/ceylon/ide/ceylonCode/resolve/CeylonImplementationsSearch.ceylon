import ceylon.interop.java {
    CeylonIterable
}

import com.intellij.openapi.application {
    ApplicationManager
}
import com.intellij.psi {
    PsiElement,
    PsiClass
}
import com.intellij.psi.search.searches {
    DefinitionsScopedSearch {
        SearchParameters
    }
}
import com.intellij.util {
    Processor,
    QueryExecutor
}
import com.redhat.ceylon.compiler.typechecker.context {
    PhasedUnit
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Node,
    Tree
}
import com.redhat.ceylon.ide.common.typechecker {
    ExternalPhasedUnit
}
import com.redhat.ceylon.ide.common.util {
    FindSubtypesVisitor,
    FindRefinementsVisitor
}
import com.redhat.ceylon.model.typechecker.model {
    TypeDeclaration,
    TypedDeclaration
}

import java.lang {
    Runnable
}

import org.intellij.plugins.ceylon.ide.ceylonCode.model {
    findProjectForFile
}
import org.intellij.plugins.ceylon.ide.ceylonCode.psi {
    CeylonTreeUtil {
        findPsiElement,
        getDeclaringFile
    },
    CeylonFile,
    CeylonPsi
}

shared class CeylonImplementationsSearch()
        satisfies QueryExecutor<PsiElement,SearchParameters> {

    shared actual Boolean execute(SearchParameters queryParameters,
                                  Processor<PsiElement> consumer) {
        findImplementors(queryParameters.element, consumer.process);
        return true;
    }

    void findImplementors(PsiElement sourceElement, void consumer(PsiElement element)) {
        if (is PsiClass sourceElement) {
            object nameGetter satisfies Runnable {
                shared variable String? qualifiedName = null;
                run() => qualifiedName = sourceElement.qualifiedName;
            }
            ApplicationManager.application.runReadAction(nameGetter);

            if (exists name = nameGetter.qualifiedName,
                exists psiFile = sourceElement.containingFile,
                exists project = findProjectForFile(psiFile),
                exists modules = project.modules,
                exists file = project.projectFileFromNative(psiFile.virtualFile),
                exists unit = file.unit,
                is TypeDeclaration|TypedDeclaration decl
                        = CeylonIterable(unit.declarations)
                            .find((d) => d.name exists
                                      //TODO is this correct:
                                      && d.qualifiedNameString.replaceLast("::", ".") == name)) {

                if (exists pus = project.typechecker?.phasedUnits) {
                    scanPhasedUnits {
                        pus = CeylonIterable(pus.phasedUnits);
                        decl = decl;
                        node = null;
                        sourceElement = sourceElement;
                        consumer = consumer;
                    };
                }
            }
        }
        else if (is CeylonPsi.DeclarationPsi sourceElement,
            exists node = sourceElement.ceylonNode,
            is TypeDeclaration|TypedDeclaration decl = node.declarationModel,
            is CeylonFile ceylonFile = sourceElement.containingFile,
            exists project = findProjectForFile(ceylonFile),
            exists modules = project.modules) {

            if (exists pus = project.typechecker?.phasedUnits) {
                scanPhasedUnits {
                    pus = CeylonIterable(pus.phasedUnits);
                    decl = decl;
                    node = node;
                    sourceElement = sourceElement;
                    consumer = consumer;
                };
            }

            if (is ExternalPhasedUnit pu = ceylonFile.localAnalysisResult?.lastPhasedUnit) {
                for (mod in modules) {
                    scanPhasedUnits {
                        pus = mod.phasedUnits;
                        decl = decl;
                        node = node;
                        sourceElement = sourceElement;
                        consumer = consumer;
                    };
                }
            }
        }
    }

    void scanPhasedUnits({PhasedUnit*} pus, TypeDeclaration|TypedDeclaration decl, Tree.Declaration? node,
        PsiElement sourceElement, void consumer(PsiElement element)) {

        for (pu in pus) {
            Set<Node> declarationNodes;
            switch (decl)
            case (is TypeDeclaration) {
                value vis = FindSubtypesVisitor(decl);
                pu.compilationUnit.visit(vis);
                declarationNodes = vis.declarationNodes;
            }
            case (is TypedDeclaration) {
                value vis = FindRefinementsVisitor(decl);
                pu.compilationUnit.visit(vis);
                declarationNodes = vis.declarationNodes;
            }
            for (dnode in declarationNodes) {
                if (exists node) {
                    if (dnode==node) {
                        continue;
                    }
                    if (is Tree.Declaration dnode,
                        dnode.declarationModel.qualifiedNameString
                            == decl.qualifiedNameString) {
                        continue;
                    }
                }
                object run satisfies Runnable {
                    shared actual void run() {
                        value declaringFile = getDeclaringFile(dnode.unit, sourceElement.project);
                        if (is CeylonFile declaringFile) {
                            declaringFile.ensureTypechecked();
                        }
                        consumer(findPsiElement(dnode, declaringFile));
                    }
                }
                ApplicationManager.application.runReadAction(run);
            }
        }
    }
}
