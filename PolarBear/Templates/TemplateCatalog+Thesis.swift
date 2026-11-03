//
//  TemplateCatalog+Thesis.swift
//  PolarBear
//

extension TemplateCatalog {
    static let thesisMain = #"""
\documentclass[11pt]{report}
\usepackage[margin=1in]{geometry}
\usepackage{amsmath}

\title{Report Title}
\author{Your Name}
\date{\today}

\begin{document}
\maketitle
\tableofcontents

\input{chapters/introduction}
\input{chapters/methods}

\bibliographystyle{plain}
\bibliography{references}

\end{document}
"""#

    static let thesisIntroduction = #"""
\chapter{Introduction}
This chapter lives in its own file, \texttt{chapters/introduction.tex}, and is pulled into
the main document with \verb|\input|. It cites a reference~\cite{knuth1984}.
"""#

    static let thesisMethods = #"""
\chapter{Methods}
\section{Approach}
Describe what you did.

\section{Analysis}
The same note applies: this chapter is a separate file. Citing a second work~\cite{lamport1994}.
"""#

    static let thesisReferences = #"""
@book{knuth1984,
  author    = {Donald E. Knuth},
  title     = {The {\TeX}book},
  publisher = {Addison-Wesley},
  year      = {1984}
}

@book{lamport1994,
  author    = {Leslie Lamport},
  title     = {{\LaTeX}: A Document Preparation System},
  publisher = {Addison-Wesley},
  year      = {1994},
  edition   = {2nd}
}
"""#
}
